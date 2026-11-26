import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/active_chat_selection.dart';
import '../../models/firm.dart';
import '../../models/membership.dart';
import '../../models/notice_model.dart';
import '../../screens/employee/channel_chat_screen.dart';
import '../../screens/notices/notice_composer_screen.dart';
import '../../screens/notices/notice_detail_screen.dart';
import '../../services/db_service.dart';
import '../../services/notices_service.dart';
import '../../services/urgent_notice_notifier_service.dart';
import '../../theme/pc_tokens.dart';
import '../../widgets/chat/unified_chat_view.dart';
import '../../widgets/common/pc_logo.dart';
import '../../widgets/notices/notice_card.dart';
import '../search_page.dart';

/// Home tab serving as the workspace portal and official noticeboard.
/// Adapts between full-bleed mobile scroll and centered max-width Web canvas.
class EmployeeHomeTab extends StatefulWidget {
  final String uid;
  final String userName;
  final Firm firm;
  final void Function(int tabIndex) onNavigateToTab;
  final ValueChanged<ActiveChatSelection>? onOpenChat;
  final bool isWideLayout;

  const EmployeeHomeTab({
    super.key,
    required this.uid,
    required this.userName,
    required this.firm,
    required this.onNavigateToTab,
    this.onOpenChat,
    this.isWideLayout = false,
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

    _memberSub = DBService.instance
        .streamMember(widget.firm.firmId, widget.uid)
        .listen((doc) {
      if (doc.exists && mounted) {
        final newMembership = Membership.fromFirestore(doc);
        final shouldRefresh = _myMembership == null ||
            _myMembership?.departmentId != newMembership.departmentId;
        setState(() {
          _myMembership = newMembership;
        });
        _listenUrgentNotice();
        if (shouldRefresh) {
          _loadInitialData(forceRefresh: true);
        }
      }
    });

    _lastSeenSub = NoticesService.instance
        .streamLastSeenAt(widget.firm.firmId, widget.uid)
        .listen((lastSeen) {
      if (mounted) {
        setState(() => _lastSeenAt = lastSeen);
      }
    });

    _loadInitialData();
    NoticesService.instance.updateLastSeenAt(widget.firm.firmId, widget.uid);

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
    final tokens = context.pcTokens;
    final primaryColor = tokens.primary;

    Widget scrollBody = RefreshIndicator(
      color: primaryColor,
      backgroundColor: tokens.surface,
      onRefresh: () async {
        await _loadInitialData(forceRefresh: true);
        await NoticesService.instance.updateLastSeenAt(
          widget.firm.firmId,
          widget.uid,
        );
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isWideLayout ? 28 : 16,
              vertical: widget.isWideLayout ? 20 : 12,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildGreetingCard(tokens),
                const SizedBox(height: 14),
                if (_urgentNotice != null &&
                    !_urgentDismissed &&
                    !_urgentNotice!.isExpired) ...[
                  _buildUrgentBanner(_urgentNotice!, tokens),
                  const SizedBox(height: 14),
                ],
                _buildQuickLinks(tokens),
                const SizedBox(height: 22),
                if (_pinnedNotices.isNotEmpty) ...[
                  _buildPinnedSection(tokens),
                  const SizedBox(height: 22),
                ],
                Row(
                  children: [
                    Icon(Icons.feed_outlined, color: tokens.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Notices',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (_notices.isNotEmpty)
                      Text(
                        '${_notices.length} notices',
                        style: TextStyle(color: tokens.textMuted, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          if (_isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              ),
            )
          else if (_notices.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyFeedState(tokens),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isWideLayout ? 28 : 16,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _notices.length) {
                      return _isFetchingMore
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              ),
                            )
                          : const SizedBox(height: 80);
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
    );

    if (widget.isWideLayout) {
      scrollBody = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: scrollBody,
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        titleSpacing: widget.isWideLayout ? 24 : 16,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: tokens.border),
        ),
        title: Row(
          children: [
            PcLogo(
              logo: widget.firm.logo,
              legacyUrl: widget.firm.logoUrl,
              firmName: widget.firm.name,
              width: 34,
              height: 34,
              borderRadius: 10,
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
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Workspace Portal',
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: tokens.textSecondary),
            tooltip: 'Search colleagues',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchPage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _canPublish
          ? FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: tokens.onPrimary,
              elevation: 2,
              icon: const Icon(Icons.campaign_rounded, size: 20),
              label: const Text(
                'Post Notice',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
      body: scrollBody,
    );
  }

  Widget _buildGreetingCard(PcTokens tokens) {
    final firstName = widget.userName.split(' ').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.primarySoft,
            tokens.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tokens.primaryBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.primaryBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: tokens.primary),
                    const SizedBox(width: 6),
                    Text(
                      widget.firm.name,
                      style: TextStyle(
                        color: tokens.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_myMembership != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Text(
                    _myMembership!.role.name.toUpperCase(),
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_getGreeting()}, $firstName!',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Official company announcements, updates, and department notices.',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentBanner(NoticeModel notice, PcTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.urgentBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.urgentBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.urgentText.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: tokens.urgentText,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'URGENT NOTICE',
                      style: TextStyle(
                        color: tokens.urgentText,
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
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _openNoticeDetail(notice),
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.urgentText,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'View Notice',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        UrgentNoticeNotifierService.instance
                            .dismissLocally(notice.id);
                        setState(() => _urgentDismissed = true);
                      },
                      child: Text(
                        'Dismiss',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11.5,
                        ),
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

  Widget _buildQuickLinks(PcTokens tokens) {
    final deptId = _myMembership?.departmentId;

    return Row(
      children: [
        Expanded(
          child: _QuickLinkCard(
            title: '#all-staff',
            subtitle: 'Company',
            icon: Icons.campaign_rounded,
            iconColor: tokens.infoAccent,
            tokens: tokens,
            onTap: () async {
              await DBService.instance.ensureAllStaffChannel(widget.firm.firmId);
              if (!mounted) return;
              if (widget.onOpenChat != null) {
                widget.onOpenChat!(ActiveChatSelection.allStaff());
                return;
              }
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
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickLinkCard(
            title: deptId != null ? 'Department' : 'Team Chat',
            subtitle: deptId != null ? 'My Team' : 'Open Chat',
            icon: Icons.corporate_fare_rounded,
            iconColor: tokens.primary,
            tokens: tokens,
            onTap: () async {
              if (deptId != null) {
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
                  if (widget.onOpenChat != null) {
                    widget.onOpenChat!(
                      ActiveChatSelection(
                        kind: UnifiedChatKind.department,
                        conversationId: convId,
                        title: name,
                        subtitle: 'Department Channel',
                        departmentId: deptId,
                      ),
                    );
                    return;
                  }
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
              if (widget.onOpenChat != null) {
                widget.onOpenChat!(
                  ActiveChatSelection.general(
                    widget.firm.firmId,
                    widget.firm.name,
                  ),
                );
                return;
              }
              widget.onNavigateToTab(1);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickLinkCard(
            title: 'Message',
            subtitle: 'Direct Chats',
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF0D9488),
            tokens: tokens,
            onTap: () => widget.onNavigateToTab(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickLinkCard(
            title: 'Directory',
            subtitle: 'Colleagues',
            icon: Icons.people_outline_rounded,
            iconColor: tokens.projectAccent,
            tokens: tokens,
            onTap: () => widget.onNavigateToTab(2),
          ),
        ),
      ],
    );
  }

  Widget _buildPinnedSection(PcTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.push_pin_rounded, color: tokens.warningAccent, size: 18),
            const SizedBox(width: 6),
            Text(
              'Pinned Notices',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: tokens.warningSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_pinnedNotices.length}',
                style: TextStyle(
                  color: tokens.warningAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pinnedNotices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final notice = _pinnedNotices[index];
              return _PinnedNoticeCard(
                notice: notice,
                tokens: tokens,
                onTap: () => _openNoticeDetail(notice),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFeedState(PcTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_rounded,
                color: tokens.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'All Caught Up!',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'There are no active notices for your audience right now.\nPull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final PcTokens tokens;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
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
                color: tokens.textMuted,
                fontSize: 10.5,
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
  final PcTokens tokens;
  final VoidCallback onTap;

  const _PinnedNoticeCard({
    required this.notice,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 252,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: tokens.warningAccent.withValues(alpha: 0.35),
            width: 1,
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
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notice.audienceSummary,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.push_pin_rounded, color: tokens.warningAccent, size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notice.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
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
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tokens.textMuted, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
