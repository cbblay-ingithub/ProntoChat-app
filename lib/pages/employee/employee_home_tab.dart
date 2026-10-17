import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../models/membership.dart';
import '../../models/notice_model.dart';
import '../../services/db_service.dart';
import '../../services/notices_service.dart';
import '../../services/urgent_notice_notifier_service.dart';
import '../../widgets/notices/notice_card.dart';
import '../../screens/notices/notice_detail_screen.dart';
import '../../screens/notices/notice_composer_screen.dart';
import '../../screens/employee/channel_chat_screen.dart';
import '../search_page.dart';
import '../../widgets/common/pc_logo.dart';

/// The redesigned Home tab that serves as the default landing screen for all members.
/// Features:
/// - Workspace header with firm branding and colleague search
/// - Urgent notice banner (addressed, unacknowledged, dismissible locally)
/// - Quick links row (#all-staff, My Department, Direct Chats, Directory)
/// - Pinned notices carousel (up to 3 pinned unexpired notices)
/// - Main feed of notice cards with pull-to-refresh & pagination
/// - Role & permission gated FAB for posting notices (admin, lead, or noticePublisher)
class EmployeeHomeTab extends StatefulWidget {
  final String uid;
  final String userName;
  final Firm firm;
  final void Function(int tabIndex) onNavigateToTab;

  const EmployeeHomeTab({
    super.key,
    required this.uid,
    required this.userName,
    required this.firm,
    required this.onNavigateToTab,
  });

  @override
  State<EmployeeHomeTab> createState() => _EmployeeHomeTabState();
}

class _EmployeeHomeTabState extends State<EmployeeHomeTab> {
  final ScrollController _scrollController = ScrollController();

  List<NoticeModel> _notices = [];
  List<NoticeModel> _pinnedNotices = [];
  NoticeModel? _urgentNotice;
  bool _urgentDismissed = false;

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  DateTime? _lastSeenAt;
  StreamSubscription? _lastSeenSub;
  StreamSubscription? _urgentSub;
  StreamSubscription? _memberSub;
  Membership? _myMembership;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 1. Listen to membership to know user's role and department
    _memberSub = DBService.instance
        .streamMember(widget.firm.firmId, widget.uid)
        .listen((doc) {
      if (doc.exists && mounted) {
        final newMembership = Membership.fromFirestore(doc);
        final shouldRefresh = _myMembership == null || _myMembership?.departmentId != newMembership.departmentId;
        setState(() {
          _myMembership = newMembership;
        });
        // Start urgent notice listener with resolved department
        _listenUrgentNotice();
        if (shouldRefresh) {
          _loadInitialData(forceRefresh: true);
        }
      }
    });

    // 2. Stream user's lastSeenAt for unread badge calculation
    _lastSeenSub = NoticesService.instance
        .streamLastSeenAt(widget.firm.firmId, widget.uid)
        .listen((lastSeen) {
      if (mounted) {
        setState(() => _lastSeenAt = lastSeen);
      }
    });

    // 3. Initial load of feed & pinned notices
    _loadInitialData();

    // 4. Update lastSeenAt (throttled to at most once per 60s)
    NoticesService.instance.updateLastSeenAt(widget.firm.firmId, widget.uid);

    // 5. Start foreground urgent notifier for alerts & haptics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      UrgentNoticeNotifierService.instance.startListening(
        firmId: widget.firm.firmId,
        userDepartmentId: _myMembership?.departmentId,
        context: context,
        onOpenNotice: _openNoticeDetail,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _lastSeenSub?.cancel();
    _urgentSub?.cancel();
    _memberSub?.cancel();
    UrgentNoticeNotifierService.instance.stopListening();
    super.dispose();
  }

  void _listenUrgentNotice() {
    _urgentSub?.cancel();
    _urgentSub = NoticesService.instance
        .streamLatestUrgentNotice(
          firmId: widget.firm.firmId,
          userDepartmentId: _myMembership?.departmentId,
        )
        .listen((notice) {
      if (mounted) {
        setState(() {
          _urgentNotice = notice;
          if (notice != null &&
              UrgentNoticeNotifierService.instance.isDismissed(notice.id)) {
            _urgentDismissed = true;
          }
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_isFetchingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreNotices();
    }
  }

  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final deptId = _myMembership?.departmentId;

      final results = await Future.wait([
        NoticesService.instance.fetchFeedNotices(
          firmId: widget.firm.firmId,
          userDepartmentId: deptId,
          limit: 10,
          forceRefresh: forceRefresh,
        ),
        NoticesService.instance.fetchPinnedNotices(
          firmId: widget.firm.firmId,
          userDepartmentId: deptId,
        ),
      ]);

      if (mounted) {
        final feed = results[0];
        final pinned = results[1];

        setState(() {
          _notices = feed;
          _pinnedNotices = pinned;
          _hasMore = feed.length >= 10;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[EmployeeHomeTab] Error loading notices: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreNotices() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final deptId = _myMembership?.departmentId;
      final moreNotices = await NoticesService.instance.fetchFeedNotices(
        firmId: widget.firm.firmId,
        userDepartmentId: deptId,
        limit: 10,
        startAfterDoc: _lastDoc,
      );

      if (mounted) {
        setState(() {
          _notices.addAll(moreNotices);
          _hasMore = moreNotices.length >= 10;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[EmployeeHomeTab] Error loading more notices: $e');
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  void _openNoticeDetail(NoticeModel notice) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(
          notice: notice,
          firm: widget.firm,
          currentUid: widget.uid,
          currentUserName: widget.userName,
          currentUserRole: _myMembership?.role.name ?? 'employee',
        ),
      ),
    );

    // Refresh feed if notice was retracted or modified
    if (result == true && mounted) {
      _loadInitialData(forceRefresh: true);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool get _canPublish {
    if (_myMembership == null) return false;
    return _myMembership!.canPublishNotices;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            PcLogo(
              logo: widget.firm.logo,
              legacyUrl: widget.firm.logoUrl,
              firmName: widget.firm.name,
              width: 34,
              height: 34,
              borderRadius: 17,
              fallbackColor: primaryColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.firm.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Workspace Portal',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Search colleagues',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _canPublish
          ? FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.campaign, size: 22),
              label: const Text(
                'Post Notice',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoticeComposerScreen(
                      firm: widget.firm,
                      currentUid: widget.uid,
                      currentUserName: widget.userName,
                      currentUserRole: _myMembership?.role.name ?? 'employee',
                      currentUserDepartmentId: _myMembership?.departmentId,
                      canTargetFirmWide: _myMembership?.isAdmin == true ||
                          (_myMembership?.isLead == true &&
                              widget.firm.leadsMayTargetBeyondOwnDepartment),
                    ),
                  ),
                );

                if (created != null && mounted) {
                  _loadInitialData(forceRefresh: true);
                }
              },
            )
          : null,
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: const Color.fromRGBO(38, 37, 37, 1),
        onRefresh: () async {
          await _loadInitialData(forceRefresh: true);
          await NoticesService.instance.updateLastSeenAt(widget.firm.firmId, widget.uid);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── 1. Greeting Card ───────────────────────────────────────
                  _buildGreetingCard(primaryColor),

                  const SizedBox(height: 14),

                  // ── 2. Urgent Notice Banner (if active & not dismissed) ────
                  if (_urgentNotice != null &&
                      !_urgentDismissed &&
                      !_urgentNotice!.isExpired) ...[
                    _buildUrgentBanner(_urgentNotice!),
                    const SizedBox(height: 14),
                  ],

                  // ── 3. Quick Links Row ─────────────────────────────────────
                  _buildQuickLinks(primaryColor),

                  const SizedBox(height: 20),

                  // ── 4. Pinned Notices Carousel ─────────────────────────────
                  if (_pinnedNotices.isNotEmpty) ...[
                    _buildPinnedSection(primaryColor),
                    const SizedBox(height: 22),
                  ],

                  // ── 5. Main Notices Feed Header ────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.feed_outlined, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Recent Notices',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (_notices.isNotEmpty)
                        Text(
                          '${_notices.length} notices',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ]),
              ),
            ),

            // ── 6. Notices Feed Items ────────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_notices.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyFeedState(primaryColor),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _notices.length) {
                        return _isFetchingMore
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const SizedBox(height: 80); // spacing for FAB
                      }

                      final notice = _notices[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: NoticeCard(
                          notice: notice,
                          lastSeenAt: _lastSeenAt,
                          primaryColor: primaryColor,
                          onTap: () => _openNoticeDetail(notice),
                        ),
                      );
                    },
                    childCount: _notices.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Greeting Card ──────────────────────────────────────────────────────────
  Widget _buildGreetingCard(Color primaryColor) {
    final firstName = widget.userName.split(' ').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.22),
            const Color.fromRGBO(38, 37, 37, 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      widget.firm.name,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_myMembership != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _myMembership!.role.name.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_getGreeting()}, $firstName!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Official company announcements, updates, and department notices.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ── Urgent Notice Banner ───────────────────────────────────────────────────
  Widget _buildUrgentBanner(NoticeModel notice) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(48, 20, 20, 1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'URGENT NOTICE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'from ${notice.authorName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _openNoticeDetail(notice),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'View Notice',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        UrgentNoticeNotifierService.instance.dismissLocally(notice.id);
                        setState(() => _urgentDismissed = true);
                      },
                      child: Text(
                        'Dismiss',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Links Row ────────────────────────────────────────────────────────
  Widget _buildQuickLinks(Color primaryColor) {
    final deptId = _myMembership?.departmentId;

    return Row(
      children: [
        // #all-staff
        Expanded(
          child: _QuickLinkCard(
            title: '#all-staff',
            subtitle: 'Company',
            icon: Icons.campaign,
            iconColor: Colors.blueAccent,
            onTap: () async {
              await DBService.instance.ensureAllStaffChannel(widget.firm.firmId);
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChannelChatScreen(
                      channelType: ChannelType.allStaff,
                      firmId: widget.firm.firmId,
                      conversationId: 'all_staff',
                      title: '#all-staff',
                      uid: widget.uid,
                      userName: widget.userName,
                    ),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // Department
        Expanded(
          child: _QuickLinkCard(
            title: deptId != null ? 'Department' : 'Channels',
            subtitle: deptId != null ? 'My Team' : 'All Chats',
            icon: Icons.corporate_fare,
            iconColor: primaryColor,
            onTap: () async {
              if (deptId != null) {
                // Fetch department conversationId
                final doc = await FirebaseFirestore.instance
                    .collection('Firms')
                    .doc(widget.firm.firmId)
                    .collection('departments')
                    .doc(deptId)
                    .get();
                final data = doc.data() ?? {};
                final convId = data['conversationId'] as String?;
                final name = data['name'] as String? ?? 'Department';

                if (convId != null && convId.isNotEmpty && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChannelChatScreen(
                        channelType: ChannelType.department,
                        firmId: widget.firm.firmId,
                        conversationId: convId,
                        title: name,
                        uid: widget.uid,
                        userName: widget.userName,
                        departmentId: deptId,
                      ),
                    ),
                  );
                  return;
                }
              }
              // Fallback: Navigate to Chats tab
              widget.onNavigateToTab(1);
            },
          ),
        ),
        const SizedBox(width: 8),

        // Direct Messages
        Expanded(
          child: _QuickLinkCard(
            title: 'Messages',
            subtitle: 'Direct Chats',
            icon: Icons.chat_bubble_outline,
            iconColor: Colors.tealAccent,
            onTap: () => widget.onNavigateToTab(1), // Switch to Chats tab
          ),
        ),
        const SizedBox(width: 8),

        // Directory
        Expanded(
          child: _QuickLinkCard(
            title: 'Directory',
            subtitle: 'Colleagues',
            icon: Icons.people_outline,
            iconColor: Colors.purpleAccent,
            onTap: () => widget.onNavigateToTab(2), // Switch to Directory tab
          ),
        ),
      ],
    );
  }

  // ── Pinned Notices Carousel ────────────────────────────────────────────────
  Widget _buildPinnedSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.push_pin, color: Colors.amberAccent, size: 18),
            const SizedBox(width: 6),
            const Text(
              'Pinned Notices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_pinnedNotices.length}',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pinnedNotices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final notice = _pinnedNotices[index];
              return _PinnedNoticeCard(
                notice: notice,
                primaryColor: primaryColor,
                onTap: () => _openNoticeDetail(notice),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Empty Feed State ───────────────────────────────────────────────────────
  Widget _buildEmptyFeedState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.task_alt, color: primaryColor, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'All Caught Up!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'There are no active notices for your audience right now.\nPull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-Widgets ──────────────────────────────────────────────────────────────

class _QuickLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(36, 35, 35, 1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedNoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final Color primaryColor;
  final VoidCallback onTap;

  const _PinnedNoticeCard({
    required this.notice,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(34, 33, 33, 1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.amberAccent.withOpacity(0.3),
            width: 1.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notice.audienceSummary,
                    style: TextStyle(color: Colors.grey[300], fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.push_pin, color: Colors.amberAccent, size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notice.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.25,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    notice.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
