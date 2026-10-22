import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/firm.dart';
import '../../providers/firm/providers.dart';
import '../../services/chat_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/pc_logo.dart';
import '../../pages/home_page.dart';

/// Navigation Shell for the Admin Management Hub.
/// Supports collapsible left rail (expanded and icon-only modes),
/// active sliding indicator, tooltips, responsive drawer for mobile/tablet,
/// firm branding at the top, and account/logout area at the bottom.
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
  // Whether left rail is collapsed (icon only) or expanded (icon + label)
  bool _isCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<({String title, IconData icon, String route})> _destinations = [
    (title: 'Dashboard', icon: Icons.dashboard_outlined, route: '/admin/dashboard'),
    (title: 'Onboarding', icon: Icons.person_add_alt_1_outlined, route: '/admin/onboarding'),
    (title: 'Notices & Groups', icon: Icons.campaign_outlined, route: '/admin/notices'),
    (title: 'Customization', icon: Icons.palette_outlined, route: '/admin/brand'),
  ];

  Color _hexToColor(String hexString, [Color fallback = const Color(0xFF295CB4)]) {
    try {
      String clean = hexString.toUpperCase().replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      if (clean.length == 8) {
        final val = int.tryParse(clean, radix: 16);
        if (val != null) return Color(val);
      }
    } catch (_) {}
    return fallback;
  }

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of ProntoChat?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
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
          SnackbarService().showSnackbar('Error logging out: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firm = ref.watch(currentFirmProvider);
    final primaryColor = firm != null ? _hexToColor(firm.primaryColor) : const Color(0xFF295CB4);
    final currentIdx = widget.navigationShell.currentIndex;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFF141313),
        canvasColor: const Color(0xFF1A1919),
        cardColor: const Color(0xFF1E1D1D),
        dialogBackgroundColor: const Color(0xFF222121),
        colorScheme: Theme.of(context).colorScheme.copyWith(
          surface: const Color(0xFF1E1D1D),
          onSurface: Colors.white,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF141313),
        drawer: isCompact
            ? Drawer(
                backgroundColor: const Color(0xFF1A1919),
                child: Material(
                  color: Colors.transparent,
                  child: _buildNavigationContent(context, firm, primaryColor, isDrawer: true),
                ),
              )
            : null,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C1B1B),
          elevation: 0,
          centerTitle: false,
          leading: isCompact
              ? IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  tooltip: 'Open Navigation',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                )
              : IconButton(
                  icon: Icon(_isCollapsed ? Icons.menu_open : Icons.menu, color: Colors.white70),
                  tooltip: _isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                  onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _destinations[currentIdx].title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    firm?.name ?? 'Admin Hub',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
              tooltip: 'Open Team Chats',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'Sign Out',
              onPressed: () => _handleLogout(context),
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
                width: _isCollapsed ? 72 : 230,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1919),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: _buildNavigationContent(context, firm, primaryColor, isDrawer: false),
                ),
              ),
            Expanded(
              child: Material(
                color: const Color(0xFF141313),
                child: PageTransitionSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
                    return FadeThroughTransition(
                      animation: primaryAnimation,
                      secondaryAnimation: secondaryAnimation,
                      child: child,
                    );
                  },
                  child: widget.navigationShell,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationContent(
    BuildContext context,
    Firm? firm,
    Color primaryColor, {
    required bool isDrawer,
  }) {
    final currentIdx = widget.navigationShell.currentIndex;
    final showLabels = isDrawer || !_isCollapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Firm Brand Header (minimalistic and rightsized)
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: showLabels ? 14 : 10,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: showLabels ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              PcLogo(
                logo: firm?.logo,
                legacyUrl: firm?.logoUrl,
                size: 30,
                borderRadius: 8,
                variant: MediaVariant.logoSm,
                firmName: firm?.name ?? 'P',
                primaryColor: primaryColor,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Management Hub',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
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
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final dest = _destinations[index];
              final isSelected = currentIdx == index;

              final itemWidget = Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (isDrawer) Navigator.of(context).pop();
                    _onDestinationSelected(index);
                  },
                  borderRadius: BorderRadius.circular(10),
                  hoverColor: Colors.white.withOpacity(0.04),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: showLabels ? 14 : 0,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor.withOpacity(0.16) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? primaryColor.withOpacity(0.4) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: showLabels ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        Icon(
                          dest.icon,
                          size: 20,
                          color: isSelected ? primaryColor : Colors.grey[400],
                        ),
                        if (showLabels) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dest.title,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[300],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                                color: primaryColor,
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
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Chat shortcut
              Tooltip(
                message: 'Open Team Chats',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: showLabels ? 8 : 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.lightGreenAccent),
                  title: showLabels
                      ? const Text(
                          'Team Chats',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        )
                      : null,
                  onTap: () {
                    if (isDrawer) Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
                    );
                  },
                ),
              ),
              // Sign out
              Tooltip(
                message: 'Sign Out',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: showLabels ? 8 : 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                  title: showLabels
                      ? const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        )
                      : null,
                  onTap: () => _handleLogout(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
