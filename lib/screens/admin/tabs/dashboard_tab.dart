import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/firm.dart';
import '../../../models/audit_entry.dart';
import '../../../models/dashboard_metrics_models.dart';
import '../../../providers/firm/providers.dart';
import '../../../providers/dashboard/dashboard_providers.dart';
import '../../../services/db_service.dart';
import '../../../services/snackbar_service.dart';
import '../../../screens/notices/notice_composer_screen.dart';
import '../../../widgets/dashboard/dashboard_tokens.dart';
import '../../../widgets/dashboard/dashboard_header_strip.dart';
import '../../../widgets/dashboard/metric_card.dart';
import '../../../widgets/dashboard/section_card.dart';
import '../../../widgets/dashboard/chart_card.dart';
import '../../../widgets/dashboard/seat_usage_meter.dart';
import '../../../widgets/dashboard/skeleton_card.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  String? _adminName;
  bool _checklistDismissed = false;

  @override
  void initState() {
    super.initState();
    _fetchAdminName();
  }

  Future<void> _fetchAdminName() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      try {
        final userDoc = await DBService.instance.getUserData(currentUid);
        if (mounted && userDoc != null) {
          setState(() {
            _adminName = userDoc['name'] as String?;
          });
        }
      } catch (_) {}
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final firm = ref.watch(currentFirmProvider);
    if (firm == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final primaryColor = DashboardTokens.hexToColor(firm.primaryColor);
    final dashboardAsync = ref.watch(dashboardMetricsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(dashboardMetricsProvider.notifier).refreshDashboard(force: true);
      },
      color: DashboardTokens.accentGreen,
      backgroundColor: DashboardTokens.surfaceCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: DashboardTokens.space24,
          vertical: DashboardTokens.space24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: DashboardTokens.maxContentWidth),
            child: dashboardAsync.when(
              loading: () => _buildLoadingState(firm, primaryColor),
              error: (err, _) => _buildErrorState(err.toString(), primaryColor),
              data: (bundle) => _buildDashboardContent(context, firm, primaryColor, bundle),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Firm firm, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardHeaderStrip(
          firm: firm,
          adminName: _adminName,
          primaryColor: primaryColor,
          isRefreshing: true,
        ),
        const SizedBox(height: DashboardTokens.space16),
        const Row(
          children: [
            Expanded(child: SkeletonCard(height: 110)),
            SizedBox(width: DashboardTokens.space12),
            Expanded(child: SkeletonCard(height: 110)),
            SizedBox(width: DashboardTokens.space12),
            Expanded(child: SkeletonCard(height: 110)),
            SizedBox(width: DashboardTokens.space12),
            Expanded(child: SkeletonCard(height: 110)),
          ],
        ),
        const SizedBox(height: DashboardTokens.space20),
        const SkeletonCard(height: 140),
        const SizedBox(height: DashboardTokens.space20),
        const Row(
          children: [
            Expanded(child: SkeletonCard(height: 260)),
            SizedBox(width: DashboardTokens.space16),
            Expanded(child: SkeletonCard(height: 260)),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(String message, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(DashboardTokens.space32),
      decoration: BoxDecoration(
        color: DashboardTokens.surfaceDark,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
        border: Border.all(color: DashboardTokens.surfaceBorder),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: DashboardTokens.accentRed, size: 36),
            const SizedBox(height: DashboardTokens.space12),
            const Text(
              'Unable to load dashboard metrics',
              style: TextStyle(
                color: DashboardTokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DashboardTokens.space8),
            Text(
              message,
              style: const TextStyle(color: DashboardTokens.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DashboardTokens.space20),
            ElevatedButton.icon(
              onPressed: () => ref.read(dashboardMetricsProvider.notifier).loadDashboard(force: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    Firm firm,
    Color primaryColor,
    DashboardBundle bundle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Strip (Firm identity, greeting, last updated, refresh)
        DashboardHeaderStrip(
          firm: firm,
          adminName: _adminName,
          primaryColor: primaryColor,
          lastFetched: bundle.lastFetched,
        ),
        const SizedBox(height: DashboardTokens.space16),

        // 2. Headline KPIs (Total, Active, Pending, Revoked)
        _buildHeadlineKpis(context, bundle.headlineKpis, primaryColor),
        const SizedBox(height: DashboardTokens.space20),

        // 3. Quick Actions & Setup Checklist
        _buildQuickActionsAndChecklist(context, firm, primaryColor, bundle),
        const SizedBox(height: DashboardTokens.space20),

        // 4. Seat Usage Meter
        SeatUsageMeter(
          firm: firm,
          data: bundle.seatUsage,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: DashboardTokens.space20),

        // 5. Funnel Chart & Department Breakdown
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 950) {
              return Column(
                children: [
                  _buildFunnelCard(bundle.funnel),
                  const SizedBox(height: DashboardTokens.space16),
                  _buildDepartmentCard(bundle.departmentBreakdown),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildFunnelCard(bundle.funnel)),
                const SizedBox(width: DashboardTokens.space16),
                Expanded(child: _buildDepartmentCard(bundle.departmentBreakdown)),
              ],
            );
          },
        ),
        const SizedBox(height: DashboardTokens.space20),

        // 6. Joins Over Time & Role Distribution / Groups Overview
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 950) {
              return Column(
                children: [
                  _buildJoinsCard(bundle.joinsOverTime, primaryColor),
                  const SizedBox(height: DashboardTokens.space16),
                  _buildRoleAndGroupsCard(bundle.roleDistribution, bundle.groupsOverview),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildJoinsCard(bundle.joinsOverTime, primaryColor)),
                const SizedBox(width: DashboardTokens.space16),
                Expanded(child: _buildRoleAndGroupsCard(bundle.roleDistribution, bundle.groupsOverview)),
              ],
            );
          },
        ),
        const SizedBox(height: DashboardTokens.space20),

        // 7. Notices Oversight & Presence Engagement
        _buildNoticesAndPresenceRow(context, bundle.noticesOversight, bundle.presenceEngagement, primaryColor),
        const SizedBox(height: DashboardTokens.space20),

        // 8. Bottom Panels: Needs Attention & Recent Admin Activity
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 950) {
              return Column(
                children: [
                  _buildNeedsAttentionPanel(context, bundle.needsAttention),
                  const SizedBox(height: DashboardTokens.space16),
                  _buildRecentActivityPanel(context, bundle.recentActivity, primaryColor),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildNeedsAttentionPanel(context, bundle.needsAttention)),
                const SizedBox(width: DashboardTokens.space16),
                Expanded(flex: 6, child: _buildRecentActivityPanel(context, bundle.recentActivity, primaryColor)),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- 1. Headline KPIs Row ---
  Widget _buildHeadlineKpis(BuildContext context, HeadlineKpiData kpis, Color primaryColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 700;

        final items = [
          (
            title: 'Total Staff',
            count: kpis.totalStaff,
            icon: Icons.people_outline_rounded,
            color: primaryColor,
            filter: 'all',
            delta: kpis.activeDelta + kpis.pendingDelta,
          ),
          (
            title: 'Active Staff',
            count: kpis.activeStaff,
            icon: Icons.check_circle_outline_rounded,
            color: DashboardTokens.accentGreen,
            filter: 'active',
            delta: kpis.activeDelta,
          ),
          (
            title: 'Pending Staff',
            count: kpis.pendingStaff,
            icon: Icons.hourglass_top_rounded,
            color: DashboardTokens.accentOrange,
            filter: 'pending',
            delta: kpis.pendingDelta,
          ),
          (
            title: 'Revoked Staff',
            count: kpis.revokedStaff,
            icon: Icons.block_rounded,
            color: DashboardTokens.accentRed,
            filter: 'revoked',
            delta: kpis.revokedDelta,
          ),
        ];

        if (isSmall) {
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.45,
            crossAxisSpacing: DashboardTokens.space12,
            mainAxisSpacing: DashboardTokens.space12,
            children: items.map((i) {
              return MetricCard(
                title: i.title,
                count: i.count,
                icon: i.icon,
                accentColor: i.color,
                onboardingFilter: i.filter,
                weeklyDelta: i.delta,
              );
            }).toList(),
          );
        }

        return Row(
          children: items.map((i) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: MetricCard(
                  title: i.title,
                  count: i.count,
                  icon: i.icon,
                  accentColor: i.color,
                  onboardingFilter: i.filter,
                  weeklyDelta: i.delta,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- 2. Quick Actions & Setup Checklist ---
  Widget _buildQuickActionsAndChecklist(
    BuildContext context,
    Firm firm,
    Color primaryColor,
    DashboardBundle bundle,
  ) {
    final hasLogo = (firm.logo != null && firm.logo!.key.isNotEmpty) ||
        (firm.logoUrl != null && firm.logoUrl!.isNotEmpty);
    final hasDepts = bundle.departmentBreakdown.departments.isNotEmpty;
    final hasStaff = bundle.headlineKpis.totalStaff > 1 || bundle.funnel.totalInvited > 0;

    return Column(
      children: [
        // Quick Action Bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DashboardTokens.space16,
            vertical: DashboardTokens.space12,
          ),
          decoration: BoxDecoration(
            color: DashboardTokens.surfaceDark,
            borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
            border: Border.all(color: DashboardTokens.surfaceBorder),
          ),
          child: Wrap(
            spacing: DashboardTokens.space12,
            runSpacing: DashboardTokens.space12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Quick Actions:',
                style: TextStyle(
                  color: DashboardTokens.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/admin/onboarding?action=add_staff'),
                icon: const Icon(Icons.person_add_rounded, size: 15),
                label: const Text('Add Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/admin/notices?sub=departments&action=new'),
                icon: const Icon(Icons.corporate_fare_rounded, size: 15),
                label: const Text('New Department'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DashboardTokens.textPrimary,
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoticeComposerScreen(
                        firm: firm,
                        currentUid: uid,
                        currentUserName: _adminName ?? 'Admin',
                        currentUserRole: 'admin',
                        canTargetFirmWide: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.campaign_rounded, size: 15),
                label: const Text('Post Notice'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DashboardTokens.textPrimary,
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final inviteUri = 'https://officespace.chottu.link/?firmId=${firm.firmId}';
                  await Clipboard.setData(ClipboardData(text: inviteUri));
                  SnackbarService().showSnackbar('Invite link copied to clipboard!');
                },
                icon: const Icon(Icons.link_rounded, size: 15),
                label: const Text('Copy Join Link'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Setup Checklist (Dismissible)
        if (!_checklistDismissed && (!hasLogo || !hasDepts || !hasStaff)) ...[
          const SizedBox(height: DashboardTokens.space12),
          Container(
            padding: const EdgeInsets.all(DashboardTokens.space16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded, color: primaryColor, size: 18),
                        const SizedBox(width: DashboardTokens.space8),
                        const Text(
                          'Firm Setup Checklist',
                          style: TextStyle(
                            color: DashboardTokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: DashboardTokens.textMuted),
                      tooltip: 'Dismiss checklist',
                      onPressed: () => setState(() => _checklistDismissed = true),
                    ),
                  ],
                ),
                const SizedBox(height: DashboardTokens.space8),
                _buildChecklistItem(
                  title: 'Upload Firm Brand Logo',
                  done: hasLogo,
                  onTap: () => context.go('/admin/brand'),
                ),
                _buildChecklistItem(
                  title: 'Create First Department Channel',
                  done: hasDepts,
                  onTap: () => context.go('/admin/notices?sub=departments&action=new'),
                ),
                _buildChecklistItem(
                  title: 'Invite Team Members or Import CSV',
                  done: hasStaff,
                  onTap: () => context.go('/admin/onboarding'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChecklistItem({required String title, required bool done, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: done ? DashboardTokens.accentGreen : DashboardTokens.textMuted,
              ),
              const SizedBox(width: DashboardTokens.space8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: done ? DashboardTokens.textMuted : DashboardTokens.textPrimary,
                    fontSize: 13,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!done) ...[
                const SizedBox(width: DashboardTokens.space8),
                const Icon(Icons.chevron_right_rounded, size: 16, color: DashboardTokens.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. Onboarding Funnel Chart ---
  Widget _buildFunnelCard(OnboardingFunnelData funnel) {
    final stages = [
      (name: 'Total Invited', count: funnel.totalInvited, color: DashboardTokens.accentBlue),
      (name: 'Code Pending', count: funnel.codePending, color: DashboardTokens.accentOrange),
      (name: 'Joined', count: funnel.joined, color: DashboardTokens.accentGreen),
      (name: 'Expired / Unclaimed', count: funnel.expired, color: DashboardTokens.accentRed),
    ];

    final maxVal = stages.map((s) => s.count).fold<int>(0, (a, b) => a > b ? a : b);

    // Graphical Bar Chart
    final chartWidget = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxVal > 0 ? maxVal + 2 : 5).toDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => DashboardTokens.surfaceCard,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final stage = stages[group.x.toInt()];
              return BarTooltipItem(
                '${stage.name}\n${rod.toY.toInt()} staff',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= stages.length) return const SizedBox();
                final shortNames = ['Invited', 'Pending', 'Joined', 'Expired'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    shortNames[idx],
                    style: const TextStyle(color: DashboardTokens.textSecondary, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(stages.length, (i) {
          final s = stages[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: s.count.toDouble(),
                color: s.color,
                width: 26,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );

    // Accessible Table representation
    final tableWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Stage', style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
          DataColumn(label: Text('Staff Count', style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
          DataColumn(label: Text('Conversion %', style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
        ],
        rows: stages.map((s) {
          final pct = funnel.totalInvited > 0
              ? ((s.count / funnel.totalInvited) * 100).toStringAsFixed(1)
              : '0.0';
          return DataRow(
            cells: [
              DataCell(Text(s.name, style: const TextStyle(color: DashboardTokens.textPrimary, fontSize: 12))),
              DataCell(Text('${s.count}', style: const TextStyle(color: DashboardTokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(Text('$pct%', style: const TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
            ],
          );
        }).toList(),
      ),
    );

    return ChartCard(
      title: 'Onboarding Funnel',
      subtitle: 'Real PreApprovedStaff conversion (${funnel.conversionRate.toStringAsFixed(1)}% joined)',
      hasData: funnel.hasData,
      emptyMessage: 'No onboarding invite activity recorded yet.',
      height: 200,
      chart: chartWidget,
      table: tableWidget,
    );
  }

  // --- 4. Department Breakdown Chart ---
  Widget _buildDepartmentCard(DepartmentBreakdownData deptBreakdown) {
    final colors = [
      DashboardTokens.accentGreen,
      DashboardTokens.accentBlue,
      DashboardTokens.accentPurple,
      DashboardTokens.accentOrange,
      DashboardTokens.accentTeal,
      Colors.pinkAccent,
      Colors.indigoAccent,
    ];

    final depts = deptBreakdown.departments;
    final unassigned = deptBreakdown.unassignedCount;

    final allItems = [
      ...depts.map((d) => (name: d.name, count: d.count)),
      if (unassigned > 0) (name: 'Unassigned', count: unassigned),
    ];

    final totalActive = allItems.fold<int>(0, (a, b) => a + b.count);

    final chartWidget = Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: List.generate(allItems.length, (i) {
                final item = allItems[i];
                final count = item.count.toDouble();
                final color = item.name == 'Unassigned'
                    ? DashboardTokens.textMuted
                    : colors[i % colors.length];

                return PieChartSectionData(
                  value: count > 0 ? count : 0.01,
                  color: color,
                  title: count > 0 ? '${count.toInt()}' : '',
                  radius: 36,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: DashboardTokens.space12),
        Expanded(
          flex: 5,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allItems.length,
            itemBuilder: (context, i) {
              final item = allItems[i];
              final color = item.name == 'Unassigned'
                  ? DashboardTokens.textMuted
                  : colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(color: DashboardTokens.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.count}',
                      style: const TextStyle(
                        color: DashboardTokens.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );

    final tableWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Department', style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
          DataColumn(label: Text('Active Staff', style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
          DataColumn(label: Text('Share %', style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
        ],
        rows: allItems.map((item) {
          final pct = totalActive > 0
              ? ((item.count / totalActive) * 100).toStringAsFixed(1)
              : '0.0';
          return DataRow(
            cells: [
              DataCell(Text(item.name, style: const TextStyle(color: DashboardTokens.textPrimary, fontSize: 12))),
              DataCell(Text('${item.count}', style: const TextStyle(color: DashboardTokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(Text('$pct%', style: const TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
            ],
          );
        }).toList(),
      ),
    );

    return ChartCard(
      title: 'Department Headcounts',
      subtitle: unassigned > 0
          ? 'Active staff distribution ($unassigned unassigned)'
          : 'Active staff distributed across active departments',
      hasData: deptBreakdown.hasData,
      emptyMessage: 'No active staff in departments yet.',
      height: 200,
      chart: chartWidget,
      table: tableWidget,
    );
  }

  // --- 5. Joins Over Time Chart ---
  Widget _buildJoinsCard(JoinsOverTimeData joins, Color primaryColor) {
    final currentWeeks = joins.requestedWeeks;

    final trailingSelector = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: currentWeeks,
          dropdownColor: DashboardTokens.surfaceCard,
          icon: const Icon(Icons.arrow_drop_down, color: DashboardTokens.textSecondary, size: 16),
          style: const TextStyle(color: DashboardTokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          onChanged: (val) {
            if (val != null) {
              ref.read(dashboardMetricsProvider.notifier).setJoinsWeeks(val);
            }
          },
          items: const [
            DropdownMenuItem(value: 4, child: Text('4 Weeks')),
            DropdownMenuItem(value: 8, child: Text('8 Weeks')),
            DropdownMenuItem(value: 12, child: Text('12 Weeks')),
          ],
        ),
      ),
    );

    final maxVal = joins.weeklyBuckets.map((b) => b.count).fold<int>(0, (a, b) => a > b ? a : b);

    final chartWidget = Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: (maxVal > 0 ? maxVal + 2 : 5).toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withOpacity(0.05),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= joins.weeklyBuckets.length) return const SizedBox();
                      final bucket = joins.weeklyBuckets[idx];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${bucket.weekStart.day}/${bucket.weekStart.month}',
                          style: const TextStyle(color: DashboardTokens.textMuted, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: DashboardTokens.accentGreen,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 3.5,
                      color: DashboardTokens.accentGreen,
                      strokeWidth: 1.5,
                      strokeColor: DashboardTokens.surfaceDark,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: DashboardTokens.accentGreen.withOpacity(0.12),
                  ),
                  spots: List.generate(joins.weeklyBuckets.length, (i) {
                    return FlSpot(i.toDouble(), joins.weeklyBuckets[i].count.toDouble());
                  }),
                ),
              ],
            ),
          ),
        ),
        if (joins.excludedNoJoinDateCount > 0) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ℹ️ ${joins.excludedNoJoinDateCount} active member(s) joined prior to this window or lack a recorded join date.',
              style: const TextStyle(color: DashboardTokens.textMuted, fontSize: 10.5),
            ),
          ),
        ],
      ],
    );

    final tableWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Week Starting', style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
          DataColumn(label: Text('New Staff Joined', style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12))),
        ],
        rows: joins.weeklyBuckets.map((b) {
          return DataRow(
            cells: [
              DataCell(Text(_formatDate(b.weekStart), style: const TextStyle(color: DashboardTokens.textPrimary, fontSize: 12))),
              DataCell(Text('${b.count}', style: const TextStyle(color: DashboardTokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          );
        }).toList(),
      ),
    );

    return ChartCard(
      title: 'Joins Over Time',
      subtitle: 'New members joining per week (Monday 00:00 local cut-off)',
      trailing: trailingSelector,
      hasData: joins.hasData,
      emptyMessage: 'No members joined in the selected window.',
      height: 200,
      chart: chartWidget,
      table: tableWidget,
    );
  }

  // --- 6. Role Distribution & Groups Overview ---
  Widget _buildRoleAndGroupsCard(RoleDistributionData roleDist, GroupsOverviewData groups) {
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
          // Section A: Role Distribution
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: DashboardTokens.accentBlue),
              SizedBox(width: DashboardTokens.space8),
              Text(
                'Role Distribution',
                style: TextStyle(
                  color: DashboardTokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: DashboardTokens.space12),
          Row(
            children: [
              _buildRolePill('Admins', roleDist.adminCount, DashboardTokens.accentRed),
              const SizedBox(width: DashboardTokens.space8),
              _buildRolePill('Leads', roleDist.leadCount, DashboardTokens.accentOrange),
              const SizedBox(width: DashboardTokens.space8),
              _buildRolePill('Staff', roleDist.employeeCount, DashboardTokens.accentGreen),
            ],
          ),

          const SizedBox(height: DashboardTokens.space20),
          const Divider(height: 1, color: DashboardTokens.surfaceDivider),
          const SizedBox(height: DashboardTokens.space16),

          // Section B: Groups Overview (Active & Archived)
          const Row(
            children: [
              Icon(Icons.hub_outlined, size: 18, color: DashboardTokens.accentPurple),
              SizedBox(width: DashboardTokens.space8),
              Text(
                'Groups & Channels Overview',
                style: TextStyle(
                  color: DashboardTokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: DashboardTokens.space12),
          Row(
            children: [
              Expanded(
                child: _buildGroupStatTile(
                  'Departments',
                  groups.activeDepartments,
                  groups.archivedDepartments,
                  '/admin/notices?sub=departments',
                ),
              ),
              const SizedBox(width: DashboardTokens.space12),
              Expanded(
                child: _buildGroupStatTile(
                  'Project Groups',
                  groups.activeProjects,
                  groups.archivedProjects,
                  '/admin/notices?sub=projects',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRolePill(String role, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              role,
              style: const TextStyle(
                color: DashboardTokens.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupStatTile(String label, int active, int archived, String route) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
            border: Border.all(color: DashboardTokens.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: DashboardTokens.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$active active',
                    style: const TextStyle(
                      color: DashboardTokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$archived archived',
                    style: const TextStyle(color: DashboardTokens.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 7. Notices Oversight & Presence Row ---
  Widget _buildNoticesAndPresenceRow(
    BuildContext context,
    NoticesOversightData notices,
    PresenceEngagementData presence,
    Color primaryColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 950) {
          return Column(
            children: [
              _buildNoticesOversightCard(notices),
              const SizedBox(height: DashboardTokens.space16),
              _buildPresenceCard(presence),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _buildNoticesOversightCard(notices)),
            const SizedBox(width: DashboardTokens.space16),
            Expanded(flex: 5, child: _buildPresenceCard(presence)),
          ],
        );
      },
    );
  }

  Widget _buildNoticesOversightCard(NoticesOversightData notices) {
    return SectionCard(
      title: 'Notices Oversight',
      titleIcon: Icons.campaign_outlined,
      titleIconColor: DashboardTokens.accentGreen,
      subtitle: '${notices.publishedCount} total published notices (${notices.urgentCount} urgent)',
      trailing: TextButton.icon(
        onPressed: () => context.go('/admin/notices'),
        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
        label: const Text('All Notices', style: TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: DashboardTokens.accentGreen,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildNoticeStatBadge('Urgent', notices.urgentCount, DashboardTokens.accentRed),
              const SizedBox(width: DashboardTokens.space8),
              _buildNoticeStatBadge('Policies', notices.policyCount, DashboardTokens.accentPurple),
              const SizedBox(width: DashboardTokens.space8),
              _buildNoticeStatBadge('Standard', notices.publishedCount - (notices.urgentCount + notices.policyCount), DashboardTokens.accentBlue),
            ],
          ),
          const SizedBox(height: DashboardTokens.space16),
          if (notices.latestPolicyNoticeId != null && notices.latestPolicyAckRate != null) ...[
            Text(
              'Latest Policy Acknowledgement Rate (${notices.latestPolicyAckRate!.toStringAsFixed(1)}%)',
              style: const TextStyle(
                color: DashboardTokens.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
              child: LinearProgressIndicator(
                value: (notices.latestPolicyAckRate! / 100.0).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(DashboardTokens.accentPurple),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${notices.latestPolicyAckCount} of ${notices.activeMembersCount} active staff acknowledged',
              style: const TextStyle(color: DashboardTokens.textMuted, fontSize: 11),
            ),
          ] else ...[
            const Text(
              'No mandatory policies currently awaiting acknowledgement.',
              style: TextStyle(color: DashboardTokens.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeStatBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '${count < 0 ? 0 : count}',
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(color: DashboardTokens.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceCard(PresenceEngagementData presence) {
    return SectionCard(
      title: 'Active Engagement',
      titleIcon: Icons.bolt_outlined,
      titleIconColor: DashboardTokens.accentOrange,
      subtitle: 'Firm-level activity over the last 7 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (presence.isPrivacyDisabled) ...[
            Container(
              padding: const EdgeInsets.all(DashboardTokens.space12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                border: Border.all(color: DashboardTokens.surfaceBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 16, color: DashboardTokens.textMuted),
                  SizedBox(width: DashboardTokens.space8),
                  Expanded(
                    child: Text(
                      'Presence tracking is turned off by firm privacy settings.',
                      style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Text(
                  '${presence.activeInLast7Days ?? 0}',
                  style: const TextStyle(
                    color: DashboardTokens.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: DashboardTokens.space8),
                const Text(
                  'active staff in last 7 days',
                  style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: DashboardTokens.space8),
            const Text(
              'Privacy safe: No individual employee last-seen or activity logging.',
              style: TextStyle(color: DashboardTokens.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // --- 8. Bottom Panels: Needs Attention & Recent Activity ---
  Widget _buildNeedsAttentionPanel(BuildContext context, List<NeedsAttentionItem> items) {
    return SectionCard(
      title: 'Needs Attention',
      titleIcon: Icons.warning_amber_rounded,
      titleIconColor: DashboardTokens.accentOrange,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: DashboardTokens.accentOrange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        ),
        child: Text(
          '${items.length}',
          style: const TextStyle(
            color: DashboardTokens.accentOrange,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: DashboardTokens.space16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: DashboardTokens.accentGreen, size: 16),
                  SizedBox(width: DashboardTokens.space8),
                  Expanded(
                    child: Text(
                      'All departments, project channels, and staff invitations are in good standing.',
                      style: TextStyle(color: DashboardTokens.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length > 5 ? 5 : items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: DashboardTokens.surfaceDivider),
              itemBuilder: (context, i) {
                final item = items[i];
                IconData icon;
                Color iconColor;

                switch (item.type) {
                  case NeedsAttentionType.expiringCode:
                    icon = Icons.timer_outlined;
                    iconColor = DashboardTokens.accentRed;
                    break;
                  case NeedsAttentionType.staleInvite:
                    icon = Icons.hourglass_bottom_rounded;
                    iconColor = DashboardTokens.accentOrange;
                    break;
                  case NeedsAttentionType.departmentNoHead:
                    icon = Icons.person_search_rounded;
                    iconColor = DashboardTokens.accentOrange;
                    break;
                  case NeedsAttentionType.departmentZeroStaff:
                    icon = Icons.group_off_outlined;
                    iconColor = DashboardTokens.textSecondary;
                    break;
                  case NeedsAttentionType.projectRevokedOwner:
                    icon = Icons.lock_person_outlined;
                    iconColor = DashboardTokens.accentRed;
                    break;
                }

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: iconColor, size: 18),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      color: DashboardTokens.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    item.subtitle,
                    style: const TextStyle(color: DashboardTokens.textSecondary, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 14, color: DashboardTokens.textMuted),
                  onTap: () => context.go(item.route),
                );
              },
            ),
    );
  }

  Widget _buildRecentActivityPanel(BuildContext context, List<AuditEntry> activity, Color primaryColor) {
    return SectionCard(
      title: 'Recent Admin Activity',
      titleIcon: Icons.history_rounded,
      titleIconColor: primaryColor,
      child: activity.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: DashboardTokens.space16),
              child: Center(
                child: Text(
                  'No recorded activity yet.',
                  style: TextStyle(color: DashboardTokens.textMuted, fontSize: 12),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activity.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: DashboardTokens.surfaceDivider),
              itemBuilder: (context, i) {
                final entry = activity[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: primaryColor.withOpacity(0.15),
                    child: Icon(Icons.flash_on_rounded, size: 12, color: primaryColor),
                  ),
                  title: Text(
                    entry.humanDescription,
                    style: const TextStyle(color: DashboardTokens.textPrimary, fontSize: 12),
                  ),
                  trailing: Text(
                    _formatDate(entry.createdAt),
                    style: const TextStyle(color: DashboardTokens.textMuted, fontSize: 11),
                  ),
                );
              },
            ),
    );
  }
}
