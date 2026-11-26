import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;

import '../models/active_chat_selection.dart';
import '../models/firm.dart';
import '../providers/auth_provider.dart';
import '../providers/firm/providers.dart';
import '../screens/employee/channel_chat_screen.dart';
import '../screens/employee/firm_chat_screen.dart';
import '../screens/employee/mentions_screen.dart';
import '../services/db_service.dart';
import '../services/notices_service.dart';
import '../theme/pc_tokens.dart';
import '../widgets/chat/unified_chat_view.dart';
import '../widgets/common/pc_avatar.dart';
import '../widgets/common/pc_logo.dart';
import 'employee/employee_chats_tab.dart';
import 'employee/employee_directory_tab.dart';
import 'employee/employee_home_tab.dart';
import 'employee/employee_profile_tab.dart';

/// Adaptive Employee Workspace Shell for Unified Flutter (Mobile + Tablet + Web).
/// - Compact (< 680px): Mobile bottom NavigationBar + native stack pushes.
/// - Medium (680px - 1080px): Left Workspace Rail + active section / split chat view.
/// - Expanded (>= 1080px): 3-Pane Slack/Linear Workspace (Collapsible Rail + Persistent
///   Channels/DMs Sidebar + Active Stage, plus optional Colleague Inspector on ultra-wide).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// 0 = Home, 1 = Chats/Messages, 2 = Directory, 3 = Profile, 4 = Mentions (Web/Rail)
  int _currentIndex = 0;
  bool _railExpanded = false;
  bool _showRightDirectoryInspector = false;
  ActiveChatSelection? _activeChat;

  void _navigateToTab(int index) {
    if (index >= 0 && index <= 4) {
      setState(() => _currentIndex = index);
    }
  }

  void _openChatInline(ActiveChatSelection selection) {
    setState(() {
      _activeChat = selection;
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = provider.Provider.of<AuthProvider>(context);
    final tokens = context.pcTokens;
    final primaryColor = tokens.primary;

    if (auth.isInitializing || auth.isAuthenticating) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    final String uid = auth.currentUserId ?? 'emp_alex_101';
    final String userName =
        auth.currentUserName.isNotEmpty ? auth.currentUserName : 'Alex Morgan';
    final String userEmail =
        (auth.currentUserEmail != null && auth.currentUserEmail!.isNotEmpty)
            ? auth.currentUserEmail!
            : 'alex.morgan@workspace.com';
    final String? userImage =
        auth.currentUserImage.isNotEmpty ? auth.currentUserImage : null;

    final Firm? activeFirm = ref.watch(currentFirmProvider);
    if (activeFirm == null) {
      final membershipData = ref.watch(myMembershipStreamProvider).value?.data();
      final memberFirmId = membershipData?['firmId'] as String?;
      if (memberFirmId != null && memberFirmId.isNotEmpty) {
        ref.read(firmNotifierProvider.notifier).loadFirm(memberFirmId);
        return Scaffold(
          backgroundColor: tokens.canvas,
          body: Center(
            child: CircularProgressIndicator(color: primaryColor),
          ),
        );
      }
    }

    final Firm firm = activeFirm ??
        Firm(
          firmId: 'firm_workspace_101',
          name: 'ProntoChat Workspace',
          primaryColor: '#2563EB',
          adminId: 'admin_101',
          createdAt: DateTime.now(),
        );

    final effectiveChat =
        _activeChat ?? ActiveChatSelection.general(firm.firmId, firm.name);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (PcBreakpoints.isCompact(width)) {
          return _buildMobileLayout(
            context: context,
            tokens: tokens,
            uid: uid,
            userName: userName,
            userEmail: userEmail,
            userImage: userImage,
            firm: firm,
          );
        }

        if (PcBreakpoints.isMedium(width)) {
          return _buildMediumLayout(
            context: context,
            tokens: tokens,
            width: width,
            uid: uid,
            userName: userName,
            userEmail: userEmail,
            userImage: userImage,
            firm: firm,
            effectiveChat: effectiveChat,
          );
        }

        return _buildExpandedThreePaneLayout(
          context: context,
          tokens: tokens,
          width: width,
          uid: uid,
          userName: userName,
          userEmail: userEmail,
          userImage: userImage,
          firm: firm,
          effectiveChat: effectiveChat,
        );
      },
    );
  }

  // ── 1. COMPACT MOBILE LAYOUT (< 680px) ─────────────────────────────────────
  Widget _buildMobileLayout({
    required BuildContext context,
    required PcTokens tokens,
    required String uid,
    required String userName,
    required String userEmail,
    required String? userImage,
    required Firm firm,
  }) {
    final mobileIndex = _currentIndex > 3 ? 1 : _currentIndex;

    final List<Widget> tabs = [
      EmployeeHomeTab(
        uid: uid,
        userName: userName,
        firm: firm,
        onNavigateToTab: _navigateToTab,
      ),
      EmployeeChatsTab(
        uid: uid,
        userName: userName,
        firm: firm,
      ),
      EmployeeDirectoryTab(
        uid: uid,
        userName: userName,
        userImage: userImage,
        firm: firm,
      ),
      EmployeeProfileTab(
        uid: uid,
        userName: userName,
        email: userEmail,
        firm: firm,
      ),
    ];

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: IndexedStack(
        index: mobileIndex,
        children: tabs,
      ),
      bottomNavigationBar: StreamBuilder<DateTime?>(
        stream: NoticesService.instance.streamLastSeenAt(firm.firmId, uid),
        builder: (context, noticeSnap) {
          final lastSeen = noticeSnap.data;
          final bool hasUnreadNotice = NoticesService.instance.cachedFeed
              .any((n) => n.isNewFor(lastSeen));

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: DBService.instance.streamUnreadMentions(
              firmId: firm.firmId,
              uid: uid,
            ),
            builder: (context, mentionSnap) {
              final unreadMentions = mentionSnap.data?.docs.length ?? 0;

              return Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  border: Border(
                    top: BorderSide(color: tokens.border, width: 1),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: mobileIndex,
                  onDestinationSelected: _navigateToTab,
                  backgroundColor: tokens.surface,
                  indicatorColor: tokens.primarySoft,
                  elevation: 0,
                  destinations: [
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: hasUnreadNotice,
                        smallSize: 7,
                        backgroundColor: tokens.primary,
                        child: Icon(Icons.home_outlined, color: tokens.textMuted),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: hasUnreadNotice,
                        smallSize: 7,
                        backgroundColor: tokens.primary,
                        child: Icon(Icons.home_rounded, color: tokens.primary),
                      ),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: unreadMentions > 0,
                        label: Text('$unreadMentions', style: const TextStyle(fontSize: 10)),
                        backgroundColor: tokens.primary,
                        textColor: tokens.onPrimary,
                        child: Icon(Icons.chat_bubble_outline_rounded, color: tokens.textMuted),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: unreadMentions > 0,
                        label: Text('$unreadMentions', style: const TextStyle(fontSize: 10)),
                        backgroundColor: tokens.primary,
                        textColor: tokens.onPrimary,
                        child: Icon(Icons.chat_bubble_rounded, color: tokens.primary),
                      ),
                      label: 'Chats',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline_rounded, color: tokens.textMuted),
                      selectedIcon: Icon(Icons.people_rounded, color: tokens.primary),
                      label: 'Directory',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded, color: tokens.textMuted),
                      selectedIcon: Icon(Icons.person_rounded, color: tokens.primary),
                      label: 'Profile',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── 2. MEDIUM TABLET / NARROW WEB LAYOUT (680px - 1080px) ──────────────────
  Widget _buildMediumLayout({
    required BuildContext context,
    required PcTokens tokens,
    required double width,
    required String uid,
    required String userName,
    required String userEmail,
    required String? userImage,
    required Firm firm,
    required ActiveChatSelection effectiveChat,
  }) {
    final bool canSplitChats = width >= 880;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Row(
        children: [
          _buildWorkspaceRail(
            tokens: tokens,
            firm: firm,
            uid: uid,
            userName: userName,
            userImage: userImage,
            expanded: false,
            allowExpandToggle: false,
          ),
          VerticalDivider(width: 1, thickness: 1, color: tokens.border),
          Expanded(
            child: _currentIndex == 1 && canSplitChats
                ? Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: EmployeeChatsTab(
                          uid: uid,
                          userName: userName,
                          firm: firm,
                          isEmbeddedPane: true,
                          selectedChat: effectiveChat,
                          onSelectChat: _openChatInline,
                        ),
                      ),
                      VerticalDivider(width: 1, thickness: 1, color: tokens.border),
                      Expanded(
                        child: _buildInlineChatStage(
                          tokens: tokens,
                          firm: firm,
                          uid: uid,
                          userName: userName,
                          selection: effectiveChat,
                          canToggleInspector: false,
                        ),
                      ),
                    ],
                  )
                : _buildStageContent(
                    tokens: tokens,
                    uid: uid,
                    userName: userName,
                    userEmail: userEmail,
                    userImage: userImage,
                    firm: firm,
                    effectiveChat: effectiveChat,
                    isThreePane: false,
                    canToggleInspector: false,
                  ),
          ),
        ],
      ),
    );
  }

  // ── 3. EXPANDED 3-PANE SLACK / LINEAR WEB WORKSPACE (>= 1080px) ────────────
  Widget _buildExpandedThreePaneLayout({
    required BuildContext context,
    required PcTokens tokens,
    required double width,
    required String uid,
    required String userName,
    required String userEmail,
    required String? userImage,
    required Firm firm,
    required ActiveChatSelection effectiveChat,
  }) {
    final bool isUltraWide = width >= PcBreakpoints.ultraWide;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Row(
        children: [
          // PANE 1: Collapsible Branded Workspace Rail
          _buildWorkspaceRail(
            tokens: tokens,
            firm: firm,
            uid: uid,
            userName: userName,
            userImage: userImage,
            expanded: _railExpanded,
            allowExpandToggle: true,
          ),
          VerticalDivider(width: 1, thickness: 1, color: tokens.border),

          // PANE 2: Persistent Channels, Projects & Direct Messages Sidebar
          SizedBox(
            width: 316,
            child: EmployeeChatsTab(
              uid: uid,
              userName: userName,
              firm: firm,
              isEmbeddedPane: true,
              selectedChat: _currentIndex == 1 ? effectiveChat : null,
              onSelectChat: _openChatInline,
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: tokens.border),

          // PANE 3: Active Workspace Stage (Messages, Notices Feed, Directory, Mentions, Profile)
          Expanded(
            child: _buildStageContent(
              tokens: tokens,
              uid: uid,
              userName: userName,
              userEmail: userEmail,
              userImage: userImage,
              firm: firm,
              effectiveChat: effectiveChat,
              isThreePane: true,
              canToggleInspector: isUltraWide,
            ),
          ),

          // OPTIONAL RIGHT INSPECTOR (Ultra-Wide Colleague Quick Directory while in Chat)
          if (isUltraWide && _currentIndex == 1 && _showRightDirectoryInspector) ...[
            VerticalDivider(width: 1, thickness: 1, color: tokens.border),
            SizedBox(
              width: 296,
              child: EmployeeDirectoryTab(
                uid: uid,
                userName: userName,
                userImage: userImage,
                firm: firm,
                isCompactInspector: true,
                onOpenDirectChat: _openChatInline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageContent({
    required PcTokens tokens,
    required String uid,
    required String userName,
    required String userEmail,
    required String? userImage,
    required Firm firm,
    required ActiveChatSelection effectiveChat,
    required bool isThreePane,
    required bool canToggleInspector,
  }) {
    switch (_currentIndex) {
      case 0:
        return EmployeeHomeTab(
          uid: uid,
          userName: userName,
          firm: firm,
          onNavigateToTab: _navigateToTab,
          onOpenChat: _openChatInline,
          isWideLayout: true,
        );
      case 1:
        if (!isThreePane) {
          // On narrow medium tablets (< 880px), show conversation list if no explicit selection yet
          if (_activeChat == null) {
            return EmployeeChatsTab(
              uid: uid,
              userName: userName,
              firm: firm,
              onSelectChat: _openChatInline,
            );
          }
          return _buildInlineChatStage(
            tokens: tokens,
            firm: firm,
            uid: uid,
            userName: userName,
            selection: _activeChat!,
            canToggleInspector: false,
            onBackToList: () => setState(() => _activeChat = null),
          );
        }
        return _buildInlineChatStage(
          tokens: tokens,
          firm: firm,
          uid: uid,
          userName: userName,
          selection: effectiveChat,
          canToggleInspector: canToggleInspector,
        );
      case 2:
        return EmployeeDirectoryTab(
          uid: uid,
          userName: userName,
          userImage: userImage,
          firm: firm,
          isWideLayout: true,
          onOpenDirectChat: _openChatInline,
        );
      case 3:
        return EmployeeProfileTab(
          uid: uid,
          userName: userName,
          email: userEmail,
          firm: firm,
          isWideLayout: true,
        );
      case 4:
        return MentionsScreen(
          firmId: firm.firmId,
          uid: uid,
          userName: userName,
          isEmbeddedPane: true,
          onOpenChat: _openChatInline,
        );
      default:
        return EmployeeHomeTab(
          uid: uid,
          userName: userName,
          firm: firm,
          onNavigateToTab: _navigateToTab,
          onOpenChat: _openChatInline,
          isWideLayout: true,
        );
    }
  }

  Widget _buildInlineChatStage({
    required PcTokens tokens,
    required Firm firm,
    required String uid,
    required String userName,
    required ActiveChatSelection selection,
    required bool canToggleInspector,
    VoidCallback? onBackToList,
  }) {
    final Widget trailingAction = canToggleInspector
        ? IconButton(
            tooltip: _showRightDirectoryInspector
                ? 'Hide Colleague Directory'
                : 'Show Colleague Directory',
            icon: Icon(
              _showRightDirectoryInspector
                  ? Icons.view_sidebar_rounded
                  : Icons.view_sidebar_outlined,
              color: _showRightDirectoryInspector
                  ? tokens.primary
                  : tokens.textSecondary,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _showRightDirectoryInspector = !_showRightDirectoryInspector;
              });
            },
          )
        : const SizedBox.shrink();

    if (selection.kind == UnifiedChatKind.general) {
      return FirmChatScreen(
        key: ValueKey('general_${selection.conversationId}'),
        firmId: firm.firmId,
        uid: uid,
        name: userName,
        isEmbedded: onBackToList == null,
        onBack: onBackToList,
        extraAction: canToggleInspector ? trailingAction : null,
      );
    }

    if (selection.kind == UnifiedChatKind.allStaff ||
        selection.kind == UnifiedChatKind.department ||
        selection.kind == UnifiedChatKind.project) {
      final channelType = switch (selection.kind) {
        UnifiedChatKind.allStaff => ChannelType.allStaff,
        UnifiedChatKind.department => ChannelType.department,
        _ => ChannelType.project,
      };

      return ChannelChatScreen(
        key: ValueKey('${selection.kind.name}_${selection.conversationId}'),
        channelType: channelType,
        firmId: firm.firmId,
        conversationId: selection.conversationId,
        title: selection.title,
        subtitle: selection.subtitle,
        uid: uid,
        userName: userName,
        departmentId: selection.departmentId,
        projectId: selection.projectId,
        projectOwnerUid: selection.projectOwnerUid,
        isEmbedded: onBackToList == null,
        onBack: onBackToList,
        extraAction: canToggleInspector ? trailingAction : null,
      );
    }

    return UnifiedChatView(
      key: ValueKey('direct_${selection.conversationId}'),
      kind: UnifiedChatKind.direct,
      firmId: firm.firmId,
      firm: firm,
      conversationId: selection.conversationId,
      title: selection.title,
      subtitle: selection.subtitle,
      otherUserId: selection.otherUserId,
      otherUserImage: selection.otherUserImage,
      currentUid: uid,
      currentUserName: userName,
      currentUserRole: 'employee',
      primaryColor: tokens.primary,
      isEmbedded: onBackToList == null,
      onBack: onBackToList,
      extraActions: canToggleInspector ? [trailingAction] : const [],
    );
  }

  // ── WORKSPACE LEFT RAIL (PANE 1) ───────────────────────────────────────────
  Widget _buildWorkspaceRail({
    required PcTokens tokens,
    required Firm firm,
    required String uid,
    required String userName,
    required String? userImage,
    required bool expanded,
    required bool allowExpandToggle,
  }) {
    final double railWidth = expanded ? 212 : 74;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: railWidth,
      color: tokens.railBg,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Firm Logo & Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
              child: Row(
                mainAxisAlignment:
                    expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  PcLogo(
                    logo: firm.logo,
                    legacyUrl: firm.logoUrl,
                    firmName: firm.name,
                    width: 38,
                    height: 38,
                    borderRadius: 11,
                    primaryColor: tokens.primary,
                    onTap: () => _navigateToTab(0),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firm.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Workspace',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: tokens.border),
            const SizedBox(height: 12),

            // Navigation Items with Unread Streams
            StreamBuilder<DateTime?>(
              stream: NoticesService.instance.streamLastSeenAt(firm.firmId, uid),
              builder: (context, noticeSnap) {
                final lastSeen = noticeSnap.data;
                final hasUnreadNotice = NoticesService.instance.cachedFeed
                    .any((n) => n.isNewFor(lastSeen));

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: DBService.instance.streamUnreadMentions(
                    firmId: firm.firmId,
                    uid: uid,
                  ),
                  builder: (context, mentionSnap) {
                    final unreadMentions = mentionSnap.data?.docs.length ?? 0;

                    return Column(
                      children: [
                        _RailNavButton(
                          label: 'Home',
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          selected: _currentIndex == 0,
                          expanded: expanded,
                          showDotBadge: hasUnreadNotice,
                          tokens: tokens,
                          onTap: () => _navigateToTab(0),
                        ),
                        const SizedBox(height: 4),
                        _RailNavButton(
                          label: 'Messages',
                          icon: Icons.chat_bubble_outline_rounded,
                          selectedIcon: Icons.chat_bubble_rounded,
                          selected: _currentIndex == 1,
                          expanded: expanded,
                          tokens: tokens,
                          onTap: () => _navigateToTab(1),
                        ),
                        const SizedBox(height: 4),
                        _RailNavButton(
                          label: 'Mentions',
                          icon: Icons.alternate_email_rounded,
                          selectedIcon: Icons.alternate_email_rounded,
                          selected: _currentIndex == 4,
                          expanded: expanded,
                          badgeCount: unreadMentions,
                          tokens: tokens,
                          onTap: () => _navigateToTab(4),
                        ),
                        const SizedBox(height: 4),
                        _RailNavButton(
                          label: 'Directory',
                          icon: Icons.people_outline_rounded,
                          selectedIcon: Icons.people_rounded,
                          selected: _currentIndex == 2,
                          expanded: expanded,
                          tokens: tokens,
                          onTap: () => _navigateToTab(2),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const Spacer(),

            if (allowExpandToggle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: IconButton(
                  tooltip: expanded ? 'Collapse rail' : 'Expand rail',
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_double_arrow_left_rounded
                        : Icons.keyboard_double_arrow_right_rounded,
                    color: tokens.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _railExpanded = !_railExpanded),
                ),
              ),

            Divider(height: 1, color: tokens.border),
            const SizedBox(height: 10),

            // Profile Footer Item
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _navigateToTab(3),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: expanded ? 10 : 0,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _currentIndex == 3 ? tokens.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          PcAvatar(
                            legacyUrl: userImage,
                            name: userName,
                            radius: 17,
                            backgroundColor: tokens.primarySoft,
                            foregroundColor: tokens.primary,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: tokens.online,
                                shape: BoxShape.circle,
                                border: Border.all(color: tokens.railBg, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (expanded) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'My Profile',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RailNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool expanded;
  final bool showDotBadge;
  final int badgeCount;
  final PcTokens tokens;
  final VoidCallback onTap;

  const _RailNavButton({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.expanded,
    this.showDotBadge = false,
    this.badgeCount = 0,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: 21,
      color: selected ? tokens.primary : tokens.textSecondary,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text(
          badgeCount > 99 ? '99+' : '$badgeCount',
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
        ),
        backgroundColor: tokens.primary,
        textColor: tokens.onPrimary,
        child: iconWidget,
      );
    } else if (showDotBadge) {
      iconWidget = Badge(
        smallSize: 7,
        backgroundColor: tokens.primary,
        child: iconWidget,
      );
    }

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          height: expanded ? 42 : 46,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
          decoration: BoxDecoration(
            color: selected ? tokens.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? Border.all(color: tokens.primaryBorder, width: 1)
                : null,
          ),
          child: expanded
              ? Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? tokens.primary : tokens.textSecondary,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(child: iconWidget),
        ),
      ),
    );

    if (expanded) return content;
    return Tooltip(message: label, child: content);
  }
}
