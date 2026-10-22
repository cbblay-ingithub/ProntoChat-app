import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/firm.dart';
import '../../providers/dashboard/dashboard_providers.dart';
import '../../services/snackbar_service.dart';
import '../common/pc_logo.dart';
import 'dashboard_tokens.dart';

/// Clean, cohesive header strip providing firm context, admin identity,
/// member since date, relative last-refreshed status, and throttled refresh.
class DashboardHeaderStrip extends ConsumerStatefulWidget {
  final Firm firm;
  final String? adminName;
  final Color primaryColor;
  final DateTime? lastFetched;
  final bool isRefreshing;

  const DashboardHeaderStrip({
    super.key,
    required this.firm,
    this.adminName,
    required this.primaryColor,
    this.lastFetched,
    this.isRefreshing = false,
  });

  @override
  ConsumerState<DashboardHeaderStrip> createState() => _DashboardHeaderStripState();
}

class _DashboardHeaderStripState extends ConsumerState<DashboardHeaderStrip> {
  bool _localRefreshing = false;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return 'Not updated yet';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _handleRefresh() async {
    if (_localRefreshing) return;
    setState(() => _localRefreshing = true);

    final initiated = await ref.read(dashboardMetricsProvider.notifier).refreshDashboard();

    if (mounted) {
      setState(() => _localRefreshing = false);
      if (!initiated) {
        SnackbarService().showSnackbar('Metrics were refreshed recently. Please wait 30s.');
      } else {
        SnackbarService().showSnackbar('Dashboard refreshed with latest data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final hasLogo = (widget.firm.logo != null && widget.firm.logo!.key.isNotEmpty) ||
        (widget.firm.logoUrl != null && widget.firm.logoUrl!.isNotEmpty);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 750;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DashboardTokens.space16,
            vertical: DashboardTokens.space12,
          ),
          decoration: BoxDecoration(
            color: DashboardTokens.surfaceDark,
            borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
            border: Border.all(color: DashboardTokens.surfaceBorder),
          ),
          child: Row(
            children: [
              // 1. Right-sized firm logo (36x36)
              PcLogo(
                logo: widget.firm.logo,
                legacyUrl: widget.firm.logoUrl,
                size: 36,
                borderRadius: DashboardTokens.radiusSm,
                variant: MediaVariant.logoSm,
                firmName: widget.firm.name,
                primaryColor: widget.primaryColor,
              ),

              const SizedBox(width: DashboardTokens.space12),

              // 2. Firm Title, Greeting, Admin, and Plan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.firm.name,
                            style: const TextStyle(
                              color: DashboardTokens.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DashboardTokens.space8),
                        _buildPlanBadge(widget.firm.plan),
                        if (!isCompact) ...[
                          const SizedBox(width: DashboardTokens.space8),
                          Text(
                            '•  Member since ${_formatDate(widget.firm.createdAt)}',
                            style: const TextStyle(
                              color: DashboardTokens.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${_getGreeting()}, ${widget.adminName ?? "Admin"}',
                          style: const TextStyle(
                            color: DashboardTokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (email.isNotEmpty && !isCompact) ...[
                          Text(
                            ' ($email)',
                            style: const TextStyle(
                              color: DashboardTokens.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Trailing Actions: Add Logo (if missing) + Last Updated & Refresh Button
              if (!hasLogo) ...[
                TextButton.icon(
                  onPressed: () => context.go('/admin/brand'),
                  icon: Icon(Icons.add_photo_alternate_outlined, size: 14, color: widget.primaryColor),
                  label: Text(
                    isCompact ? 'Logo' : 'Add Logo',
                    style: TextStyle(color: widget.primaryColor, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: DashboardTokens.space8),
              ],

              // Relative last-refreshed status
              if (!isCompact)
                Text(
                  _formatRelativeTime(widget.lastFetched),
                  style: const TextStyle(
                    color: DashboardTokens.textMuted,
                    fontSize: 11,
                  ),
                ),

              const SizedBox(width: DashboardTokens.space8),

              // Throttled Refresh Button
              Tooltip(
                message: 'Refresh metrics (throttled to 30s)',
                child: IconButton(
                  icon: _localRefreshing || widget.isRefreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(DashboardTokens.accentGreen),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18, color: DashboardTokens.textSecondary),
                  onPressed: _localRefreshing || widget.isRefreshing ? null : _handleRefresh,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(DashboardTokens.space8),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanBadge(String plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: DashboardTokens.accentGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        border: Border.all(color: DashboardTokens.accentGreen.withOpacity(0.3)),
      ),
      child: Text(
        plan.toUpperCase(),
        style: const TextStyle(
          color: DashboardTokens.accentGreen,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
