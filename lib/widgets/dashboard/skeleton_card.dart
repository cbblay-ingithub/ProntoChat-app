import 'package:flutter/material.dart';

import '../../theme/pronto_tokens.dart';
import 'dashboard_tokens.dart';

/// Lightweight skeleton placeholder matching dashboard card dimensions.
class SkeletonCard extends StatelessWidget {
  final double height;
  final double? width;
  final EdgeInsetsGeometry padding;

  const SkeletonCard({
    super.key,
    this.height = 120,
    this.width,
    this.padding = const EdgeInsets.all(DashboardTokens.space16),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.prontoTokens;

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: tokens.cardSubtleBg,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            width: 50,
            height: 28,
            decoration: BoxDecoration(
              color: tokens.cardSubtleBg,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Container(
            width: 110,
            height: 10,
            decoration: BoxDecoration(
              color: tokens.cardSubtleBg,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
