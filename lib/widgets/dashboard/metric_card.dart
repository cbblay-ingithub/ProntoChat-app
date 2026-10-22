import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dashboard_tokens.dart';

/// Interactive KPI metric card with count-up animation, status icon,
/// weekly delta badge, and direct click-through to filtered Onboarding views.
class MetricCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;
  final String onboardingFilter;
  final int? weeklyDelta;
  final String? tooltip;

  const MetricCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.onboardingFilter,
    this.weeklyDelta,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: Tooltip(
        message: tooltip ?? 'Click to view $title in Onboarding',
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.go('/admin/onboarding?filter=$onboardingFilter');
            },
            borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
            hoverColor: DashboardTokens.surfaceHover,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DashboardTokens.space16,
                vertical: DashboardTokens.space16,
              ),
              decoration: BoxDecoration(
                color: DashboardTokens.surfaceDark,
                borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
                border: Border.all(color: DashboardTokens.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Title + Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: DashboardTokens.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(DashboardTokens.space4 + 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                        ),
                        child: Icon(icon, size: 16, color: accentColor),
                      ),
                    ],
                  ),

                  const SizedBox(height: DashboardTokens.space12),

                  // Middle: Count-up Animated Value
                  disableAnimations
                      ? Text(
                          '$count',
                          style: const TextStyle(
                            color: DashboardTokens.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
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
                              style: const TextStyle(
                                color: DashboardTokens.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: DashboardTokens.space8),

                  // Bottom Row: Weekly Delta Badge & Subtle Arrow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDeltaBadge(weeklyDelta),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: DashboardTokens.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeltaBadge(int? delta) {
    if (delta == null || delta == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        ),
        child: const Text(
          'No change this week',
          style: TextStyle(
            color: DashboardTokens.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final isPositive = delta > 0;
    final badgeColor = isPositive ? DashboardTokens.accentGreen : DashboardTokens.accentOrange;
    final prefix = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 12,
            color: badgeColor,
          ),
          const SizedBox(width: 3),
          Text(
            '$prefix$delta this week',
            style: TextStyle(
              color: badgeColor,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
