import 'package:animations/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/firm.dart';
import '../../pages/home_page.dart';
import '../../providers/firm/providers.dart';
import '../../services/chat_service.dart';
import '../../services/snackbar_service.dart';
import '../../theme/admin_theme_provider.dart';
import '../../theme/pronto_palette_engine.dart';
import '../../theme/pronto_tokens.dart';
import '../../widgets/common/pc_logo.dart';

/// Navigation Shell for the Admin Management Hub (Admin Web only).
/// Watches [adminThemeProvider] and scopes the HCT harmony theme strictly to
/// Admin Web routes and the Admin Team Chats view, leaving Mobile untouched.
class AdminShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _isCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<({String title, IconData icon, String route})>
      _destinations = [
    (
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/admin/dashboard',
    ),
    (
      title: 'Onboarding',
      icon: Icons.person_add_alt_1_outlined,
      route: '/admin/onboarding',
    ),
    (
      title: 'Notices & Groups',
      icon: Icons.campaign_outlined,
      route: '/admin/notices',
    ),
    (
      title: 'Customization',
      icon: Icons.palette_outlined,
      route: '/admin/brand',
    ),
  ];

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _openAdminTeamChats(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Consumer(
          builder: (_, chatRef, _) {
            final chatTheme = chatRef.watch(adminThemeProvider);
            return Theme(
              data: chatTheme,
              child: const HomePage(),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    ThemeData adminTheme,
    ProntoTokens tokens,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: adminTheme,
        child: AlertDialog(
          backgroundColor: tokens.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.cardBorder),
          ),
          title: Text(
            'Log Out',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of ProntoChat?',
            style: TextStyle(color: tokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.danger,
                foregroundColor: tokens.onDanger,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        ChatService.instance.cancelAllSubscriptions();
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          context.go('/sign-in');
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarService()
              .showSnackbar('Error logging out: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = ref.watch(adminThemeSpecProvider);
    final themeState = ref.watch(adminThemeControllerProvider);
    final adminTheme = spec.themeData;
    final tokens = spec.tokens;
    final cs = spec.colorScheme;
    final firm = ref.watch(currentFirmProvider);

    final currentIdx = widget.navigationShell.currentIndex;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 800;

    return Theme(
      data: adminTheme,
      child: Builder(
        builder: (themedContext) => Scaffold(
          key: _scaffoldKey,
          backgroundColor: tokens.pageBg,
          drawer: isCompact
              ? Drawer(
                  backgroundColor: tokens.sidebarBg,
                  child: Material(
                    type: MaterialType.transparency,
                    child: _buildNavigationContent(
                      themedContext,
                      adminTheme,
                      tokens,
                      cs,
                      firm,
                      isDrawer: true,
                    ),
                  ),
                )
              : null,
          appBar: AppBar(
            backgroundColor: tokens.cardBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            shape: Border(bottom: BorderSide(color: tokens.cardBorder)),
            leading: isCompact
                ? IconButton(
                    icon: Icon(Icons.menu, color: tokens.textPrimary),
                    tooltip: 'Open Navigation',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  )
                : IconButton(
                    icon: Icon(
                      _isCollapsed ? Icons.menu_open : Icons.menu,
                      color: tokens.textSecondary,
                    ),
                    tooltip:
                        _isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                    onPressed: () =>
                        setState(() => _isCollapsed = !_isCollapsed),
                  ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _destinations[currentIdx].title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: cs.secondary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      firm?.name ?? 'Admin Hub',
                      style: TextStyle(
                        color: cs.onSecondaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  themeState.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: tokens.textSecondary,
                ),
                tooltip: themeState.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
                onPressed: () => ref
                    .read(adminThemeControllerProvider.notifier)
                    .setDarkMode(!themeState.isDarkMode),
              ),
              IconButton(
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: tokens.textSecondary,
                ),
                tooltip: 'Open Team Chats',
                onPressed: () => _openAdminTeamChats(themedContext),
              ),
              IconButton(
                icon: Icon(Icons.logout, color: tokens.danger),
                tooltip: 'Sign Out',
                onPressed: () =>
                    _handleLogout(themedContext, adminTheme, tokens),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (!isCompact)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: _isCollapsed ? 72 : 236,
                  decoration: BoxDecoration(
                    color: tokens.sidebarBg,
                    border: Border(
                      right: BorderSide(color: tokens.sidebarBorder, width: 1),
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: _buildNavigationContent(
                      themedContext,
                      adminTheme,
                      tokens,
                      cs,
                      firm,
                      isDrawer: false,
                    ),
                  ),
                ),
              Expanded(
                child: Material(
                  color: tokens.pageBg,
                  child: PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder:
                        (child, primaryAnimation, secondaryAnimation) {
                      return FadeThroughTransition(
                        animation: primaryAnimation,
                        secondaryAnimation: secondaryAnimation,
                        fillColor: tokens.pageBg,
                        child: child,
                      );
                    },
                    child: Padding(
                      key: ValueKey<int>(currentIdx),
                      padding: const EdgeInsets.only(top: 4),
                      child: widget.navigationShell,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationContent(
    BuildContext context,
    ThemeData adminTheme,
    ProntoTokens tokens,
    ColorScheme cs,
    Firm? firm, {
    required bool isDrawer,
  }) {
    final currentIdx = widget.navigationShell.currentIndex;
    final showLabels = isDrawer || !_isCollapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Firm Brand Header
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: showLabels ? 14 : 10,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.sidebarBorder, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                showLabels ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              PcLogo(
                logo: firm?.logo,
                legacyUrl: firm?.logoUrl,
                size: 32,
                borderRadius: 8,
                variant: MediaVariant.logoSm,
                firmName: firm?.name ?? 'P',
                primaryColor: cs.primary,
              ),
              if (showLabels) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        firm?.name ?? 'ProntoChat',
                        style: TextStyle(
                          color: tokens.sidebarFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: tokens.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Management Hub',
                              style: TextStyle(
                                color: tokens.sidebarMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Navigation Destination Items
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _destinations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final dest = _destinations[index];
              final isSelected = currentIdx == index;

              final itemWidget = Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () {
                    if (isDrawer) Navigator.of(context).pop();
                    _onDestinationSelected(index);
                  },
                  borderRadius: BorderRadius.circular(10),
                  hoverColor: tokens.cardSubtleBg,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: showLabels ? 14 : 0,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.sidebarActive
                          : ProntoPaletteEngine.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? cs.primary.withValues(alpha: 0.30)
                            : ProntoPaletteEngine.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: showLabels
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Icon(
                          dest.icon,
                          size: 20,
                          color: isSelected
                              ? tokens.sidebarActiveFg
                              : tokens.sidebarMuted,
                        ),
                        if (showLabels) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dest.title,
                              style: TextStyle(
                                color: isSelected
                                    ? tokens.sidebarActiveFg
                                    : tokens.sidebarFg,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 5,
                              height: 16,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );

              if (!showLabels) {
                return Tooltip(
                  message: dest.title,
                  preferBelow: false,
                  child: itemWidget,
                );
              }

              return itemWidget;
            },
          ),
        ),

        // Account Area at Bottom
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: showLabels ? 12 : 8,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: tokens.sidebarBorder, width: 1),
            ),
          ),
          child: Column(
            children: [
              Tooltip(
                message: 'Open Team Chats',
                child: ListTile(
                  dense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: showLabels ? 8 : 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: cs.primary,
                  ),
                  title: showLabels
                      ? Text(
                          'Team Chats',
                          style: TextStyle(
                            color: tokens.sidebarFg,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  onTap: () {
                    if (isDrawer) Navigator.of(context).pop();
                    _openAdminTeamChats(context);
                  },
                ),
              ),
              Tooltip(
                message: 'Sign Out',
                child: ListTile(
                  dense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: showLabels ? 8 : 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    Icons.logout,
                    size: 20,
                    color: tokens.danger,
                  ),
                  title: showLabels
                      ? Text(
                          'Sign Out',
                          style: TextStyle(
                            color: tokens.sidebarMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                  onTap: () => _handleLogout(context, adminTheme, tokens),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
