import 'package:flutter/material.dart';

import '../../models/dashboard_metrics_models.dart';
import '../../models/firm.dart';
import '../../theme/pronto_tokens.dart';
import 'dashboard_tokens.dart';

/// Animated seat usage meter with semantic status thresholding (<70% success,
/// 70–90% warning, >=90% danger). Out-of-sync counter discrepancies are logged
/// internally rather than displayed as a banner to admin users.
class SeatUsageMeter extends StatefulWidget {
  final Firm firm;
  final SeatUsageData data;

  const SeatUsageMeter({
    super.key,
    required this.firm,
    required this.data,
  });

  @override
  State<SeatUsageMeter> createState() => _SeatUsageMeterState();
}

class _SeatUsageMeterState extends State<SeatUsageMeter> {
  String? _lastLoggedSyncSignature;

  void _logOutOfSyncIfNeeded() {
    if (!widget.data.isOutOfSync) {
      _lastLoggedSyncSignature = null;
      return;
    }
    final sig =
        '${widget.firm.firmId}:${widget.data.trueSeatCount}:${widget.data.storedSeatCount}';
    if (_lastLoggedSyncSignature != sig) {
      _lastLoggedSyncSignature = sig;
      debugPrint(
        '[SeatUsageMeter] Live aggregate (${widget.data.trueSeatCount} active + invited) '
        'differs from firm counter (${widget.data.storedSeatCount}) for firm ${widget.firm.firmId}. '
        'Real-time aggregate count is enforced.',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _logOutOfSyncIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SeatUsageMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _logOutOfSyncIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.prontoTokens;
    final data = widget.data;
    final firm = widget.firm;
    final ratio = data.ratio;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    // Semantic status thresholding: < 70% success, 70-90% warning, >= 90% danger
    Color meterColor = tokens.success;
    Color badgeBg = tokens.successContainer;
    Color badgeFg = tokens.onSuccessContainer;
    if (ratio >= 0.90) {
      meterColor = tokens.danger;
      badgeBg = tokens.dangerContainer;
      badgeFg = tokens.onDangerContainer;
    } else if (ratio >= 0.70) {
      meterColor = tokens.warning;
      badgeBg = tokens.warningContainer;
      badgeFg = tokens.onWarningContainer;
    }

    return Container(
      padding: const EdgeInsets.all(DashboardTokens.space20),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius:
                            BorderRadius.circular(DashboardTokens.radiusSm),
                      ),
                      child: Icon(
                        Icons.workspace_premium_outlined,
                        color: badgeFg,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: DashboardTokens.space12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${firm.plan.toUpperCase()} Plan Seat Usage',
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildTrialDaysPill(tokens),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.trueSeatCount >= data.seatLimit
                                ? 'Tier capacity reached'
                                : '${data.remainingSeats} seat${data.remainingSeats == 1 ? "" : "s"} available for new staff',
                            style: TextStyle(
                              color: data.trueSeatCount >= data.seatLimit
                                  ? tokens.danger
                                  : tokens.textSecondary,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                ),
                child: Text(
                  '${data.trueSeatCount} / ${data.seatLimit} Seats Used',
                  style: TextStyle(
                    color: badgeFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DashboardTokens.space16),
          ClipRRect(
            borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
            child: disableAnimations
                ? LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: tokens.cardSubtleBg,
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
                        backgroundColor: tokens.cardSubtleBg,
                        valueColor: AlwaysStoppedAnimation<Color>(meterColor),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialDaysPill(ProntoTokens tokens) {
    return Tooltip(
      message: 'Trial expiration date not configured for firm',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.cardSubtleBg,
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 11,
              color: tokens.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Expires: –',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
