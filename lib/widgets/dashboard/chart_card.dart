import 'package:flutter/material.dart';
import 'dashboard_tokens.dart';

/// Interactive chart container with an accessible "View data as table" toggle,
/// ensuring full WCAG compliance and keyboard/screen reader accessibility.
class ChartCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget chart;
  final Widget table;
  final bool hasData;
  final String emptyMessage;
  final double height;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.chart,
    required this.table,
    this.hasData = true,
    this.emptyMessage = 'No data available yet.',
    this.height = 200,
  });

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
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
          // Header Row
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
                      style: const TextStyle(
                        color: DashboardTokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          color: DashboardTokens.textSecondary,
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
                  // Accessible Table Toggle Button
                  Tooltip(
                    message: _showTable ? 'Switch to graphical chart' : 'View accessible data table',
                    child: IconButton(
                      icon: Icon(
                        _showTable ? Icons.bar_chart_rounded : Icons.table_chart_outlined,
                        size: 18,
                        color: _showTable ? DashboardTokens.accentGreen : DashboardTokens.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showTable = !_showTable;
                        });
                      },
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(DashboardTokens.space8),
                        backgroundColor: _showTable
                            ? DashboardTokens.accentGreenMuted
                            : Colors.white.withOpacity(0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: DashboardTokens.space16),

          // Content Area
          SizedBox(
            height: widget.height,
            child: !widget.hasData
                ? Center(
                    child: Text(
                      widget.emptyMessage,
                      style: const TextStyle(
                        color: DashboardTokens.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                : (_showTable ? widget.table : widget.chart),
          ),
        ],
      ),
    );
  }
}
