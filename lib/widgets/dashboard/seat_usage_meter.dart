import 'package:flutter/material.dart';
import '../../models/dashboard_metrics_models.dart';
import '../../models/firm.dart';
import 'dashboard_tokens.dart';

/// Animated seat usage meter with dynamic color thresholding, out-of-sync alert,
/// and honest trial tier information (no placeholder expiration dates).
class SeatUsageMeter extends StatelessWidget {
  final Firm firm;
  final SeatUsageData data;
  final Color primaryColor;

  const SeatUsageMeter({
    super.key,
    required this.firm,
    required this.data,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = data.ratio;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    // Color thresholding: < 70% green/primary, 70-90% orange, >= 90% red
    Color meterColor = DashboardTokens.accentGreen;
    if (ratio >= 0.90) {
      meterColor = DashboardTokens.accentRed;
    } else if (ratio >= 0.70) {
      meterColor = DashboardTokens.accentOrange;
    }

    return Container(
      padding: const EdgeInsets.all(DashboardTokens.space20),
      decoration: BoxDecoration(
        color: DashboardTokens.surfaceDark,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
        border: Border.all(color: DashboardTokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title, Trial Badge, Seat Count Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: meterColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                      ),
                      child: Icon(Icons.workspace_premium_outlined, color: meterColor, size: 18),
                    ),
                    const SizedBox(width: DashboardTokens.space12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${firm.plan.toUpperCase()} Plan Seat Usage',
                                style: const TextStyle(
                                  color: DashboardTokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Honest Trial Days Remaining Pill
                              _buildTrialDaysPill(),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.trueSeatCount >= data.seatLimit
                                ? 'Tier capacity reached'
                                : '${data.remainingSeats} seat${data.remainingSeats == 1 ? "" : "s"} available for new staff',
                            style: TextStyle(
                              color: data.trueSeatCount >= data.seatLimit
                                  ? DashboardTokens.accentRed
                                  : DashboardTokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DashboardTokens.space12),
              // Seat Count Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: meterColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                  border: Border.all(color: meterColor.withOpacity(0.3)),
                ),
                child: Text(
                  '${data.trueSeatCount} / ${data.seatLimit} Seats Used',
                  style: TextStyle(
                    color: meterColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: DashboardTokens.space16),

          // Animated Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
            child: disableAnimations
                ? LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(meterColor),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: ratio),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(meterColor),
                      );
                    },
                  ),
          ),

          // Out-of-sync banner if true aggregate differs from firm counter
          if (data.isOutOfSync) ...[
            const SizedBox(height: DashboardTokens.space12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DashboardTokens.accentBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                border: Border.all(color: DashboardTokens.accentBlue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: DashboardTokens.accentBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live aggregate (${data.trueSeatCount} active + invited) differs from firm counter (${data.storedSeatCount}). Real-time aggregate count is enforced.',
                      style: const TextStyle(
                        color: DashboardTokens.accentBlue,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrialDaysPill() {
    // Decision #3: Do NOT invent a trial duration.
    // Firm schema currently has no trialExpiresAt field.
    return Tooltip(
      message: 'Trial expiration date not configured for firm',
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 10, color: DashboardTokens.textMuted),
            SizedBox(width: 4),
            Text(
              'Expires: –',
              style: TextStyle(
                color: DashboardTokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
