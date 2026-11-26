import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/pronto_tokens.dart';
import 'dashboard_tokens.dart';

/// Interactive KPI metric card with count-up animation, status icon,
/// weekly delta badge, friendly zero-data state, and non-overlapping header tooltip.
class MetricCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;
  final String onboardingFilter;
  final int? weeklyDelta;
  final String? tooltip;
  final String? zeroStateHint;

  const MetricCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.onboardingFilter,
    this.weeklyDelta,
    this.tooltip,
    this.zeroStateHint,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.prontoTokens;
    final cs = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isZeroWithHint = count == 0 && zeroStateHint != null;

    return RepaintBoundary(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            context.go('/admin/onboarding?filter=$onboardingFilter');
          },
          borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
          hoverColor: tokens.cardSubtleBg,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DashboardTokens.space16,
              vertical: DashboardTokens.space16,
            ),
            decoration: BoxDecoration(
              color: tokens.cardBg,
              borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header row carries the Tooltip anchored ABOVE the card so it
                // never overlaps the "No change this week" / bottom delta badge.
                Tooltip(
                  message: tooltip ?? 'View $title in Onboarding',
                  preferBelow: false,
                  verticalOffset: 22,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.all(DashboardTokens.space4 + 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(DashboardTokens.radiusSm),
                        ),
                        child: Icon(icon, size: 16, color: accentColor),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: DashboardTokens.space12),

                disableAnimations
                    ? Text(
                        '$count',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      )
                    : TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: count),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          return Text(
                            '$val',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          );
                        },
                      ),

                const SizedBox(height: DashboardTokens.space8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: isZeroWithHint
                          ? _buildZeroHintPill(cs, zeroStateHint!)
                          : _buildDeltaBadge(tokens, weeklyDelta),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: isZeroWithHint ? cs.primary : tokens.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZeroHintPill(ColorScheme cs, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
      ),
      child: Text(
        hint,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDeltaBadge(ProntoTokens tokens, int? delta) {
    if (delta == null || delta == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: tokens.cardSubtleBg,
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        ),
        child: Text(
          'No change this week',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final isPositive = delta > 0;
    final bgColor =
        isPositive ? tokens.successContainer : tokens.warningContainer;
    final fgColor =
        isPositive ? tokens.onSuccessContainer : tokens.onWarningContainer;
    final prefix = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 12,
            color: fgColor,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '$prefix$delta this week',
              style: TextStyle(
                color: fgColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
