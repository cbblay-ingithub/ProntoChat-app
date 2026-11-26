import 'package:flutter/material.dart';

import '../../theme/pronto_tokens.dart';
import 'dashboard_tokens.dart';

/// Interactive chart container with an accessible "View data as table" toggle
/// and friendly, actionable empty states for zero-data cards.
class ChartCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget chart;
  final Widget table;
  final bool hasData;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final double height;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.chart,
    required this.table,
    this.hasData = true,
    this.emptyIcon = Icons.insights_rounded,
    this.emptyTitle = 'Nothing to chart yet',
    this.emptyMessage = 'No data available yet.',
    this.emptyActionLabel,
    this.onEmptyAction,
    this.height = 200,
  });

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.prontoTokens;
    final cs = Theme.of(context).colorScheme;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.trailing != null) ...[
                    widget.trailing!,
                    const SizedBox(width: DashboardTokens.space8),
                  ],
                  if (widget.hasData)
                    Tooltip(
                      message: _showTable
                          ? 'Switch to graphical chart'
                          : 'View accessible data table',
                      preferBelow: false,
                      child: IconButton(
                        icon: Icon(
                          _showTable
                              ? Icons.bar_chart_rounded
                              : Icons.table_chart_outlined,
                          size: 18,
                          color: _showTable
                              ? cs.onPrimaryContainer
                              : tokens.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _showTable = !_showTable;
                          });
                        },
                        style: IconButton.styleFrom(
                          padding:
                              const EdgeInsets.all(DashboardTokens.space8),
                          backgroundColor: _showTable
                              ? cs.primaryContainer
                              : tokens.cardSubtleBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DashboardTokens.radiusSm,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DashboardTokens.space16),
          SizedBox(
            height: widget.height,
            child: !widget.hasData
                ? _buildFriendlyEmptyState(tokens, cs)
                : (_showTable ? widget.table : widget.chart),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendlyEmptyState(ProntoTokens tokens, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DashboardTokens.space20,
        vertical: DashboardTokens.space16,
      ),
      decoration: BoxDecoration(
        color: tokens.cardSubtleBg,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusMd),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.emptyIcon,
              size: 20,
              color: cs.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.emptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.emptyMessage,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
            ),
          ),
          if (widget.emptyActionLabel != null &&
              widget.onEmptyAction != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: widget.onEmptyAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(widget.emptyActionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
