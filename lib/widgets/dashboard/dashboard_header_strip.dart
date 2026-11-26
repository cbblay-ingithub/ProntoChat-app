import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/firm.dart';
import '../../providers/dashboard/dashboard_providers.dart';
import '../../services/snackbar_service.dart';
import '../../theme/pronto_tokens.dart';
import '../common/pc_logo.dart';
import 'dashboard_tokens.dart';

/// Clean, cohesive header strip providing firm context, admin identity,
/// member since date, relative last-refreshed status, and throttled refresh.
class DashboardHeaderStrip extends ConsumerStatefulWidget {
  final Firm firm;
  final String? adminName;
  final DateTime? lastFetched;
  final bool isRefreshing;

  const DashboardHeaderStrip({
    super.key,
    required this.firm,
    this.adminName,
    this.lastFetched,
    this.isRefreshing = false,
  });

  @override
  ConsumerState<DashboardHeaderStrip> createState() =>
      _DashboardHeaderStripState();
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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

    final initiated =
        await ref.read(dashboardMetricsProvider.notifier).refreshDashboard();

    if (mounted) {
      setState(() => _localRefreshing = false);
      if (!initiated) {
        SnackbarService()
            .showSnackbar('Metrics were refreshed recently. Please wait 30s.');
      } else {
        SnackbarService().showSnackbar('Dashboard refreshed with latest data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.prontoTokens;
    final cs = Theme.of(context).colorScheme;
    String email = '';
    try {
      email = FirebaseAuth.instance.currentUser?.email ?? '';
    } catch (_) {}

    final hasLogo =
        (widget.firm.logo != null && widget.firm.logo!.key.isNotEmpty) ||
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
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Row(
            children: [
              PcLogo(
                logo: widget.firm.logo,
                legacyUrl: widget.firm.logoUrl,
                size: 38,
                borderRadius: DashboardTokens.radiusSm,
                variant: MediaVariant.logoSm,
                firmName: widget.firm.name,
                primaryColor: cs.primary,
              ),

              const SizedBox(width: DashboardTokens.space12),

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
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DashboardTokens.space8),
                        _buildPlanBadge(cs, widget.firm.plan),
                        if (!isCompact) ...[
                          const SizedBox(width: DashboardTokens.space8),
                          Flexible(
                            child: Text(
                              '•  Member since ${_formatDate(widget.firm.createdAt)}',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${_getGreeting()}, ${widget.adminName ?? "Admin"}',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (email.isNotEmpty && !isCompact) ...[
                          Flexible(
                            child: Text(
                              ' ($email)',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              if (!hasLogo) ...[
                TextButton.icon(
                  onPressed: () => context.go('/admin/brand'),
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 15,
                    color: cs.primary,
                  ),
                  label: Text(
                    isCompact ? 'Logo' : 'Add Logo',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: DashboardTokens.space8),
              ],

              if (!isCompact)
                Text(
                  _formatRelativeTime(widget.lastFetched),
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11.5,
                  ),
                ),

              const SizedBox(width: DashboardTokens.space8),

              Tooltip(
                message: 'Refresh metrics (throttled to 30s)',
                preferBelow: false,
                child: IconButton(
                  icon: _localRefreshing || widget.isRefreshing
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(cs.primary),
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: tokens.textSecondary,
                        ),
                  onPressed: _localRefreshing || widget.isRefreshing
                      ? null
                      : _handleRefresh,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(DashboardTokens.space8),
                    backgroundColor: tokens.cardSubtleBg,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DashboardTokens.radiusSm),
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

  Widget _buildPlanBadge(ColorScheme cs, String plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
