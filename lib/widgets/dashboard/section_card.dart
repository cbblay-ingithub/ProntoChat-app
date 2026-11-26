import 'package:flutter/material.dart';

import '../../theme/pronto_tokens.dart';
import 'dashboard_tokens.dart';

/// Standard container card for dashboard sections and panels.
class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final Color? titleIconColor;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const SectionCard({
    super.key,
    this.title,
    this.titleIcon,
    this.titleIconColor,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(DashboardTokens.space20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.prontoTokens;
    final hasHeader = title != null || subtitle != null || trailing != null;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          if (hasHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (titleIcon != null) ...[
                        Icon(
                          titleIcon,
                          size: 18,
                          color: titleIconColor ?? tokens.textPrimary,
                        ),
                        const SizedBox(width: DashboardTokens.space8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: DashboardTokens.space12),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: DashboardTokens.space16),
          ],
          child,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
          hoverColor: tokens.cardSubtleBg,
          child: content,
        ),
      );
    }

    return content;
  }
}
