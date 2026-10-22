import 'package:flutter/material.dart';
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
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: DashboardTokens.surfaceDark,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
        border: Border.all(color: DashboardTokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            width: 50,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Container(
            width: 110,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
