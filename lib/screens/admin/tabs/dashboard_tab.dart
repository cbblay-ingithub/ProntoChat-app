import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/audit_entry.dart';
import '../../../models/dashboard_metrics_models.dart';
import '../../../models/firm.dart';
import '../../../providers/dashboard/dashboard_providers.dart';
import '../../../providers/firm/providers.dart';
import '../../../screens/notices/notice_composer_screen.dart';
import '../../../services/db_service.dart';
import '../../../services/snackbar_service.dart';
import '../../../theme/pronto_palette_engine.dart';
import '../../../theme/pronto_tokens.dart';
import '../../../widgets/dashboard/chart_card.dart';
import '../../../widgets/dashboard/dashboard_header_strip.dart';
import '../../../widgets/dashboard/dashboard_tokens.dart';
import '../../../widgets/dashboard/metric_card.dart';
import '../../../widgets/dashboard/seat_usage_meter.dart';
import '../../../widgets/dashboard/section_card.dart';
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
    String? currentUid;
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      currentUid = null;
    }
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.prontoTokens;
    final cs = Theme.of(context).colorScheme;
    final firm = ref.watch(currentFirmProvider);
    if (firm == null) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    final dashboardAsync = ref.watch(dashboardMetricsProvider);

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final isCompactPadding = outerConstraints.maxWidth < 760;
        final pagePad = isCompactPadding
            ? DashboardTokens.space16
            : DashboardTokens.space24;

        return RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(dashboardMetricsProvider.notifier)
                .refreshDashboard(force: true);
          },
          color: cs.primary,
          backgroundColor: tokens.cardBg,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(pagePad),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: DashboardTokens.maxContentWidth,
                ),
                child: dashboardAsync.when(
                  loading: () => _buildLoadingState(firm, isCompactPadding),
                  error: (err, _) =>
                      _buildErrorState(tokens, cs, err.toString()),
                  data: (bundle) =>
                      _buildDashboardContent(context, tokens, cs, firm, bundle),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(Firm firm, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardHeaderStrip(
          firm: firm,
          adminName: _adminName,
          isRefreshing: true,
        ),
        const SizedBox(height: DashboardTokens.space16),
        if (isCompact) ...[
          const Row(
            children: [
              Expanded(child: SkeletonCard(height: 112)),
              SizedBox(width: DashboardTokens.space12),
              Expanded(child: SkeletonCard(height: 112)),
            ],
          ),
          const SizedBox(height: DashboardTokens.space12),
          const Row(
            children: [
              Expanded(child: SkeletonCard(height: 112)),
              SizedBox(width: DashboardTokens.space12),
              Expanded(child: SkeletonCard(height: 112)),
            ],
          ),
        ] else
          const Row(
            children: [
              Expanded(child: SkeletonCard(height: 112)),
              SizedBox(width: DashboardTokens.space12),
              Expanded(child: SkeletonCard(height: 112)),
              SizedBox(width: DashboardTokens.space12),
              Expanded(child: SkeletonCard(height: 112)),
              SizedBox(width: DashboardTokens.space12),
              Expanded(child: SkeletonCard(height: 112)),
            ],
          ),
        const SizedBox(height: DashboardTokens.space20),
        const SkeletonCard(height: 140),
        const SizedBox(height: DashboardTokens.space20),
        if (isCompact) ...[
          const SkeletonCard(height: 240),
          const SizedBox(height: DashboardTokens.space16),
          const SkeletonCard(height: 240),
        ] else
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

  Widget _buildErrorState(
    ProntoTokens tokens,
    ColorScheme cs,
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.all(DashboardTokens.space32),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: tokens.danger, size: 36),
            const SizedBox(height: DashboardTokens.space12),
            Text(
              'Unable to load dashboard metrics',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DashboardTokens.space8),
            Text(
              message,
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DashboardTokens.space20),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(dashboardMetricsProvider.notifier)
                  .loadDashboard(force: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    ProntoTokens tokens,
    ColorScheme cs,
    Firm firm,
    DashboardBundle bundle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Strip (Firm identity, greeting, last updated, refresh)
        DashboardHeaderStrip(
          firm: firm,
          adminName: _adminName,
          lastFetched: bundle.lastFetched,
        ),
        const SizedBox(height: DashboardTokens.space16),

        // 2. Headline KPIs (Total, Active, Pending, Revoked)
        _buildHeadlineKpis(tokens, cs, bundle.headlineKpis),
        const SizedBox(height: DashboardTokens.space20),

        // 3. Quick Actions & Setup Checklist
        _buildQuickActionsAndChecklist(context, tokens, cs, firm, bundle),
        const SizedBox(height: DashboardTokens.space20),

        // 4. Seat Usage Meter (Out-of-sync logged internally, never shown as banner)
        SeatUsageMeter(
          firm: firm,
          data: bundle.seatUsage,
        ),
        const SizedBox(height: DashboardTokens.space20),

        // 5. Funnel Chart & Department Breakdown
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 950) {
              return Column(
                children: [
                  _buildFunnelCard(context, tokens, cs, bundle.funnel),
                  const SizedBox(height: DashboardTokens.space16),
                  _buildDepartmentCard(
                    context,
                    tokens,
                    cs,
                    bundle.departmentBreakdown,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildFunnelCard(context, tokens, cs, bundle.funnel),
                ),
                const SizedBox(width: DashboardTokens.space16),
                Expanded(
                  child: _buildDepartmentCard(
                    context,
                    tokens,
                    cs,
                    bundle.departmentBreakdown,
                  ),
                ),
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
                  _buildJoinsCard(tokens, cs, bundle.joinsOverTime),
                  const SizedBox(height: DashboardTokens.space16),
                  _buildRoleAndGroupsCard(
                    tokens,
                    cs,
                    bundle.roleDistribution,
                    bundle.groupsOverview,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildJoinsCard(tokens, cs, bundle.joinsOverTime),
                ),
                const SizedBox(width: DashboardTokens.space16),
                Expanded(
                  child: _buildRoleAndGroupsCard(
                    tokens,
                    cs,
                    bundle.roleDistribution,
                    bundle.groupsOverview,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: DashboardTokens.space20),

        // 7. Notices Oversight & Presence Engagement
        _buildNoticesAndPresenceRow(
          context,
          tokens,
          cs,
          bundle.noticesOversight,
          bundle.presenceEngagement,
        ),
        const SizedBox(height: DashboardTokens.space20),

        // 8. Bottom Panels: Needs Attention & Recent Admin Activity
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 950) {
              return Column(
                children: [
                  _buildNeedsAttentionPanel(
                    context,
                    tokens,
                    bundle.needsAttention,
                  ),
                  const SizedBox(height: DashboardTokens.space16),
                  _buildRecentActivityPanel(
                    tokens,
                    cs,
                    bundle.recentActivity,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildNeedsAttentionPanel(
                    context,
                    tokens,
                    bundle.needsAttention,
                  ),
                ),
                const SizedBox(width: DashboardTokens.space16),
                Expanded(
                  flex: 6,
                  child: _buildRecentActivityPanel(
                    tokens,
                    cs,
                    bundle.recentActivity,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- 1. Headline KPIs Row ---
  Widget _buildHeadlineKpis(
    ProntoTokens tokens,
    ColorScheme cs,
    HeadlineKpiData kpis,
  ) {
    final items = [
      (
        title: 'Total Staff',
        count: kpis.totalStaff,
        icon: Icons.people_outline_rounded,
        color: cs.primary,
        filter: 'all',
        delta: kpis.activeDelta + kpis.pendingDelta,
        zeroHint: 'No staff yet • Invite team',
      ),
      (
        title: 'Active Staff',
        count: kpis.activeStaff,
        icon: Icons.check_circle_outline_rounded,
        color: tokens.success,
        filter: 'active',
        delta: kpis.activeDelta,
        zeroHint: null,
      ),
      (
        title: 'Pending Staff',
        count: kpis.pendingStaff,
        icon: Icons.hourglass_top_rounded,
        color: tokens.warning,
        filter: 'pending',
        delta: kpis.pendingDelta,
        zeroHint: null,
      ),
      (
        title: 'Revoked Staff',
        count: kpis.revokedStaff,
        icon: Icons.block_rounded,
        color: tokens.danger,
        filter: 'revoked',
        delta: kpis.revokedDelta,
        zeroHint: null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth < 760;

        if (isTwoColumn) {
          const gap = DashboardTokens.space12;
          final itemWidth = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items.map((i) {
              return SizedBox(
                width: itemWidth,
                child: MetricCard(
                  title: i.title,
                  count: i.count,
                  icon: i.icon,
                  accentColor: i.color,
                  onboardingFilter: i.filter,
                  weeklyDelta: i.delta,
                  zeroStateHint: i.zeroHint,
                ),
              );
            }).toList(),
          );
        }

        return Row(
          children: List.generate(items.length, (idx) {
            final i = items[idx];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: idx < items.length - 1 ? DashboardTokens.space12 : 0,
                ),
                child: MetricCard(
                  title: i.title,
                  count: i.count,
                  icon: i.icon,
                  accentColor: i.color,
                  onboardingFilter: i.filter,
                  weeklyDelta: i.delta,
                  zeroStateHint: i.zeroHint,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // --- 2. Quick Actions & Setup Checklist ---
  Widget _buildQuickActionsAndChecklist(
    BuildContext context,
    ProntoTokens tokens,
    ColorScheme cs,
    Firm firm,
    DashboardBundle bundle,
  ) {
    final hasLogo = (firm.logo != null && firm.logo!.key.isNotEmpty) ||
        (firm.logoUrl != null && firm.logoUrl!.isNotEmpty);
    final hasDepts = bundle.departmentBreakdown.departments.isNotEmpty;
    final hasStaff =
        bundle.headlineKpis.totalStaff > 1 || bundle.funnel.totalInvited > 0;
    final completedSteps =
        (hasLogo ? 1 : 0) + (hasDepts ? 1 : 0) + (hasStaff ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick Action Bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DashboardTokens.space16,
            vertical: DashboardTokens.space12,
          ),
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Wrap(
            spacing: DashboardTokens.space12,
            runSpacing: DashboardTokens.space12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Quick Actions:',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Wrap(
                spacing: DashboardTokens.space8,
                runSpacing: DashboardTokens.space8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.go('/admin/onboarding?action=add_staff'),
                    icon: const Icon(Icons.person_add_rounded, size: 15),
                    label: const Text('Add Staff'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context
                        .go('/admin/notices?sub=departments&action=new'),
                    icon: const Icon(Icons.corporate_fare_rounded, size: 15),
                    label: const Text('New Department'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      String uid = '';
                      try {
                        uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                      } catch (_) {}
                      final adminTheme = Theme.of(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Theme(
                            data: adminTheme,
                            child: NoticeComposerScreen(
                              firm: firm,
                              currentUid: uid,
                              currentUserName: _adminName ?? 'Admin',
                              currentUserRole: 'admin',
                              canTargetFirmWide: true,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.campaign_rounded, size: 15),
                    label: const Text('Post Notice'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final inviteUri =
                          'https://officespace.chottu.link/?firmId=${firm.firmId}';
                      await Clipboard.setData(ClipboardData(text: inviteUri));
                      SnackbarService()
                          .showSnackbar('Invite link copied to clipboard!');
                    },
                    icon: Icon(
                      Icons.link_rounded,
                      size: 15,
                      color: cs.onSecondaryContainer,
                    ),
                    label: Text(
                      'Copy Join Link',
                      style: TextStyle(color: cs.onSecondaryContainer),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: cs.secondaryContainer,
                      side: BorderSide(
                        color: cs.secondary.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Setup Checklist (Dismissible — High-Contrast Title & Every Item Readable)
        if (!_checklistDismissed && (!hasLogo || !hasDepts || !hasStaff)) ...[
          const SizedBox(height: DashboardTokens.space12),
          Container(
            padding: const EdgeInsets.all(DashboardTokens.space16),
            decoration: BoxDecoration(
              color: tokens.cardBg,
              borderRadius: BorderRadius.circular(DashboardTokens.radiusLg),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(DashboardTokens.radiusSm),
                      ),
                      child: Icon(
                        Icons.checklist_rounded,
                        color: cs.onPrimaryContainer,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: DashboardTokens.space8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Firm Setup Checklist',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                DashboardTokens.radiusSm,
                              ),
                            ),
                            child: Text(
                              '$completedSteps of 3 done',
                              style: TextStyle(
                                color: cs.onSecondaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: tokens.textSecondary,
                      ),
                      tooltip: 'Dismiss checklist',
                      onPressed: () =>
                          setState(() => _checklistDismissed = true),
                    ),
                  ],
                ),
                const SizedBox(height: DashboardTokens.space12),
                _buildChecklistItem(
                  tokens: tokens,
                  cs: cs,
                  title: 'Upload Firm Brand Logo',
                  done: hasLogo,
                  actionLabel: 'Customize',
                  onTap: () => context.go('/admin/brand'),
                ),
                const SizedBox(height: 6),
                _buildChecklistItem(
                  tokens: tokens,
                  cs: cs,
                  title: 'Create First Department Channel',
                  done: hasDepts,
                  actionLabel: 'Create',
                  onTap: () => context
                      .go('/admin/notices?sub=departments&action=new'),
                ),
                const SizedBox(height: 6),
                _buildChecklistItem(
                  tokens: tokens,
                  cs: cs,
                  title: 'Invite Team Members or Import CSV',
                  done: hasStaff,
                  actionLabel: 'Invite',
                  onTap: () => context.go('/admin/onboarding'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChecklistItem({
    required ProntoTokens tokens,
    required ColorScheme cs,
    required String title,
    required bool done,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusMd),
        hoverColor: tokens.cardSubtleBg,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: tokens.cardSubtleBg,
            borderRadius: BorderRadius.circular(DashboardTokens.radiusMd),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: done ? tokens.success : cs.primary,
              ),
              const SizedBox(width: DashboardTokens.space12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: done ? tokens.textSecondary : tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: done ? FontWeight.w500 : FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: tokens.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: DashboardTokens.space8),
              if (done)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.successContainer,
                    borderRadius:
                        BorderRadius.circular(DashboardTokens.radiusSm),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: tokens.onSuccessContainer,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: cs.primary,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. Onboarding Funnel Chart ---
  Widget _buildFunnelCard(
    BuildContext context,
    ProntoTokens tokens,
    ColorScheme cs,
    OnboardingFunnelData funnel,
  ) {
    final stages = [
      (
        name: 'Total Invited',
        count: funnel.totalInvited,
        color: tokens.chartPalette[0],
      ),
      (
        name: 'Code Pending',
        count: funnel.codePending,
        color: tokens.warning,
      ),
      (
        name: 'Joined',
        count: funnel.joined,
        color: tokens.success,
      ),
      (
        name: 'Expired / Unclaimed',
        count: funnel.expired,
        color: tokens.danger,
      ),
    ];

    final maxVal =
        stages.map((s) => s.count).fold<int>(0, (a, b) => a > b ? a : b);

    final chartWidget = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxVal > 0 ? maxVal + 2 : 5).toDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final stage = stages[group.x.toInt()];
              return BarTooltipItem(
                '${stage.name}\n${rod.toY.toInt()} staff',
                TextStyle(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= stages.length) return const SizedBox();
                const shortNames = ['Invited', 'Pending', 'Joined', 'Expired'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    shortNames[idx],
                    style: TextStyle(color: tokens.textSecondary, fontSize: 11),
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );

    final tableWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columnSpacing: 24,
        columns: [
          DataColumn(
            label: Text(
              'Stage',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
          DataColumn(
            label: Text(
              'Staff Count',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
          DataColumn(
            label: Text(
              'Conversion %',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
        ],
        rows: stages.map((s) {
          final pct = funnel.totalInvited > 0
              ? ((s.count / funnel.totalInvited) * 100).toStringAsFixed(1)
              : '0.0';
          return DataRow(
            cells: [
              DataCell(
                Text(
                  s.name,
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${s.count}',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              DataCell(
                Text(
                  '$pct%',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );

    return ChartCard(
      title: 'Onboarding Funnel',
      subtitle: funnel.hasData
          ? 'PreApprovedStaff conversion (${funnel.conversionRate.toStringAsFixed(1)}% joined)'
          : 'Track invitations from 6-digit staff code to joined member',
      hasData: funnel.hasData,
      emptyIcon: Icons.mark_email_unread_outlined,
      emptyTitle: 'No onboarding invites yet',
      emptyMessage:
          'Add pre-approved staff or import a CSV to track invite-to-join conversion.',
      emptyActionLabel: 'Invite Staff',
      onEmptyAction: () => context.go('/admin/onboarding'),
      height: 200,
      chart: chartWidget,
      table: tableWidget,
    );
  }

  // --- 4. Department Breakdown Chart ---
  Widget _buildDepartmentCard(
    BuildContext context,
    ProntoTokens tokens,
    ColorScheme cs,
    DepartmentBreakdownData deptBreakdown,
  ) {
    final palette = tokens.chartPalette;
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
                final sliceColor = item.name == 'Unassigned'
                    ? tokens.textMuted
                    : palette[i % palette.length];
                final labelColor = ProntoPaletteEngine.contrastRatio(
                          tokens.cardBg,
                          sliceColor,
                        ) >=
                        4.5
                    ? tokens.cardBg
                    : tokens.textPrimary;

                return PieChartSectionData(
                  value: count > 0 ? count : 0.01,
                  color: sliceColor,
                  title: count > 0 ? '${count.toInt()}' : '',
                  radius: 36,
                  titleStyle: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
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
                  ? tokens.textMuted
                  : palette[i % palette.length];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.count}',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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
        columns: [
          DataColumn(
            label: Text(
              'Department',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
          DataColumn(
            label: Text(
              'Active Staff',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
          DataColumn(
            label: Text(
              'Share %',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
        ],
        rows: allItems.map((item) {
          final pct = totalActive > 0
              ? ((item.count / totalActive) * 100).toStringAsFixed(1)
              : '0.0';
          return DataRow(
            cells: [
              DataCell(
                Text(
                  item.name,
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${item.count}',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              DataCell(
                Text(
                  '$pct%',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ),
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
      emptyIcon: Icons.account_tree_outlined,
      emptyTitle: 'No department headcounts yet',
      emptyMessage:
          'Create department channels and assign active staff to see headcounts.',
      emptyActionLabel: 'Manage Departments',
      onEmptyAction: () => context.go('/admin/notices?sub=departments'),
      height: 200,
      chart: chartWidget,
      table: tableWidget,
    );
  }

  // --- 5. Joins Over Time Chart ---
  Widget _buildJoinsCard(
    ProntoTokens tokens,
    ColorScheme cs,
    JoinsOverTimeData joins,
  ) {
    final currentWeeks = joins.requestedWeeks;
    final lineColor = tokens.chartPalette[0];

    final trailingSelector = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: tokens.cardSubtleBg,
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: currentWeeks,
          isDense: true,
          dropdownColor: tokens.cardBg,
          icon: Icon(
            Icons.arrow_drop_down,
            color: tokens.textSecondary,
            size: 18,
          ),
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
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

    final maxVal = joins.weeklyBuckets
        .map((b) => b.count)
        .fold<int>(0, (a, b) => a > b ? a : b);

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
                  color: tokens.cardBorder,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (val, meta) {
                      if (val != val.roundToDouble()) {
                        return const SizedBox();
                      }
                      final idx = val.toInt();
                      if (idx < 0 || idx >= joins.weeklyBuckets.length) {
                        return const SizedBox();
                      }
                      final bucket = joins.weeklyBuckets[idx];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${bucket.weekStart.day}/${bucket.weekStart.month}',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: lineColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3.5,
                      color: lineColor,
                      strokeWidth: 1.5,
                      strokeColor: tokens.cardBg,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withValues(alpha: 0.14),
                  ),
                  spots: List.generate(joins.weeklyBuckets.length, (i) {
                    return FlSpot(
                      i.toDouble(),
                      joins.weeklyBuckets[i].count.toDouble(),
                    );
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
              '${joins.excludedNoJoinDateCount} active member(s) joined prior to this window or lack a recorded join date.',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
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
        columns: [
          DataColumn(
            label: Text(
              'Week Starting',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
          DataColumn(
            label: Text(
              'New Staff Joined',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
        ],
        rows: joins.weeklyBuckets.map((b) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  _formatDate(b.weekStart),
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${b.count}',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
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
      emptyIcon: Icons.timeline_rounded,
      emptyTitle: 'No new joins in this window',
      emptyMessage:
          'Weekly member join trends will appear once staff accept invitations.',
      height: 200,
      chart: chartWidget,
      table: tableWidget,
    );
  }

  // --- 6. Role Distribution & Groups Overview ---
  Widget _buildRoleAndGroupsCard(
    ProntoTokens tokens,
    ColorScheme cs,
    RoleDistributionData roleDist,
    GroupsOverviewData groups,
  ) {
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
          // Section A: Role Distribution
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: cs.secondary),
              const SizedBox(width: DashboardTokens.space8),
              Text(
                'Role Distribution',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DashboardTokens.space12),
          Row(
            children: [
              _buildRolePill(
                label: 'Admins',
                count: roleDist.adminCount,
                bg: cs.primaryContainer,
                fg: cs.onPrimaryContainer,
                subColor: tokens.textSecondary,
              ),
              const SizedBox(width: DashboardTokens.space8),
              _buildRolePill(
                label: 'Leads',
                count: roleDist.leadCount,
                bg: cs.secondaryContainer,
                fg: cs.onSecondaryContainer,
                subColor: tokens.textSecondary,
              ),
              const SizedBox(width: DashboardTokens.space8),
              _buildRolePill(
                label: 'Staff',
                count: roleDist.employeeCount,
                bg: cs.tertiaryContainer,
                fg: cs.onTertiaryContainer,
                subColor: tokens.textSecondary,
              ),
            ],
          ),

          const SizedBox(height: DashboardTokens.space20),
          Divider(height: 1, color: tokens.cardBorder),
          const SizedBox(height: DashboardTokens.space16),

          // Section B: Groups Overview (Active & Archived)
          Row(
            children: [
              Icon(Icons.hub_outlined, size: 18, color: cs.tertiary),
              const SizedBox(width: DashboardTokens.space8),
              Text(
                'Groups & Channels Overview',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DashboardTokens.space12),
          Row(
            children: [
              Expanded(
                child: _buildGroupStatTile(
                  tokens,
                  'Departments',
                  groups.activeDepartments,
                  groups.archivedDepartments,
                  '/admin/notices?sub=departments',
                ),
              ),
              const SizedBox(width: DashboardTokens.space12),
              Expanded(
                child: _buildGroupStatTile(
                  tokens,
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

  Widget _buildRolePill({
    required String label,
    required int count,
    required Color bg,
    required Color fg,
    required Color subColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupStatTile(
    ProntoTokens tokens,
    String label,
    int active,
    int archived,
    String route,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: tokens.cardSubtleBg,
            borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$active active',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$archived archived',
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
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
    ProntoTokens tokens,
    ColorScheme cs,
    NoticesOversightData notices,
    PresenceEngagementData presence,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 950) {
          return Column(
            children: [
              _buildNoticesOversightCard(tokens, cs, notices),
              const SizedBox(height: DashboardTokens.space16),
              _buildPresenceCard(tokens, presence),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _buildNoticesOversightCard(tokens, cs, notices),
            ),
            const SizedBox(width: DashboardTokens.space16),
            Expanded(
              flex: 5,
              child: _buildPresenceCard(tokens, presence),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoticesOversightCard(
    ProntoTokens tokens,
    ColorScheme cs,
    NoticesOversightData notices,
  ) {
    return SectionCard(
      title: 'Notices Oversight',
      titleIcon: Icons.campaign_outlined,
      titleIconColor: cs.primary,
      subtitle:
          '${notices.publishedCount} total published notices (${notices.urgentCount} urgent)',
      trailing: TextButton.icon(
        onPressed: () => context.go('/admin/notices'),
        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
        label: const Text('All Notices', style: TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildNoticeStatBadge(
                label: 'Urgent',
                count: notices.urgentCount,
                bg: tokens.dangerContainer,
                fg: tokens.onDangerContainer,
              ),
              const SizedBox(width: DashboardTokens.space8),
              _buildNoticeStatBadge(
                label: 'Policies',
                count: notices.policyCount,
                bg: cs.tertiaryContainer,
                fg: cs.onTertiaryContainer,
              ),
              const SizedBox(width: DashboardTokens.space8),
              _buildNoticeStatBadge(
                label: 'Standard',
                count: notices.publishedCount -
                    (notices.urgentCount + notices.policyCount),
                bg: cs.secondaryContainer,
                fg: cs.onSecondaryContainer,
              ),
            ],
          ),
          const SizedBox(height: DashboardTokens.space16),
          if (notices.latestPolicyNoticeId != null &&
              notices.latestPolicyAckRate != null) ...[
            Text(
              'Latest Policy Acknowledgement Rate (${notices.latestPolicyAckRate!.toStringAsFixed(1)}%)',
              style: TextStyle(
                color: tokens.textPrimary,
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
                backgroundColor: tokens.cardSubtleBg,
                valueColor: AlwaysStoppedAnimation<Color>(cs.tertiary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${notices.latestPolicyAckCount} of ${notices.activeMembersCount} active staff acknowledged',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            ),
          ] else ...[
            Text(
              'No mandatory policies currently awaiting acknowledgement.',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeStatBadge({
    required String label,
    required int count,
    required Color bg,
    required Color fg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        ),
        child: Column(
          children: [
            Text(
              '${count < 0 ? 0 : count}',
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceCard(
    ProntoTokens tokens,
    PresenceEngagementData presence,
  ) {
    return SectionCard(
      title: 'Active Engagement',
      titleIcon: Icons.bolt_outlined,
      titleIconColor: tokens.warning,
      subtitle: 'Firm-level activity over the last 7 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (presence.isPrivacyDisabled) ...[
            Container(
              padding: const EdgeInsets.all(DashboardTokens.space12),
              decoration: BoxDecoration(
                color: tokens.cardSubtleBg,
                borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
                border: Border.all(color: tokens.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 16,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(width: DashboardTokens.space8),
                  Expanded(
                    child: Text(
                      'Presence tracking is turned off by firm privacy settings.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
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
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: DashboardTokens.space8),
                Flexible(
                  child: Text(
                    'active staff in last 7 days',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DashboardTokens.space8),
            Text(
              'Privacy safe: No individual employee last-seen or activity logging.',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // --- 8. Bottom Panels: Needs Attention & Recent Activity ---
  Widget _buildNeedsAttentionPanel(
    BuildContext context,
    ProntoTokens tokens,
    List<NeedsAttentionItem> items,
  ) {
    return SectionCard(
      title: 'Needs Attention',
      titleIcon: Icons.warning_amber_rounded,
      titleIconColor: tokens.warning,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: items.isEmpty
              ? tokens.successContainer
              : tokens.warningContainer,
          borderRadius: BorderRadius.circular(DashboardTokens.radiusSm),
        ),
        child: Text(
          '${items.length}',
          style: TextStyle(
            color: items.isEmpty
                ? tokens.onSuccessContainer
                : tokens.onWarningContainer,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DashboardTokens.space16,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: tokens.success,
                    size: 17,
                  ),
                  const SizedBox(width: DashboardTokens.space8),
                  Expanded(
                    child: Text(
                      'All departments, project channels, and staff invitations are in good standing.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length > 5 ? 5 : items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: tokens.cardBorder),
              itemBuilder: (context, i) {
                final item = items[i];
                IconData icon;
                Color iconColor;

                switch (item.type) {
                  case NeedsAttentionType.expiringCode:
                    icon = Icons.timer_outlined;
                    iconColor = tokens.danger;
                    break;
                  case NeedsAttentionType.staleInvite:
                    icon = Icons.hourglass_bottom_rounded;
                    iconColor = tokens.warning;
                    break;
                  case NeedsAttentionType.departmentNoHead:
                    icon = Icons.person_search_rounded;
                    iconColor = tokens.warning;
                    break;
                  case NeedsAttentionType.departmentZeroStaff:
                    icon = Icons.group_off_outlined;
                    iconColor = tokens.textSecondary;
                    break;
                  case NeedsAttentionType.projectRevokedOwner:
                    icon = Icons.lock_person_outlined;
                    iconColor = tokens.danger;
                    break;
                }

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: iconColor, size: 18),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    item.subtitle,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: tokens.textMuted,
                  ),
                  onTap: () => context.go(item.route),
                );
              },
            ),
    );
  }

  Widget _buildRecentActivityPanel(
    ProntoTokens tokens,
    ColorScheme cs,
    List<AuditEntry> activity,
  ) {
    return SectionCard(
      title: 'Recent Admin Activity',
      titleIcon: Icons.history_rounded,
      titleIconColor: cs.primary,
      child: activity.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DashboardTokens.space16,
              ),
              child: Center(
                child: Text(
                  'No recorded activity yet.',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activity.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: tokens.cardBorder),
              itemBuilder: (context, i) {
                final entry = activity[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      Icons.flash_on_rounded,
                      size: 13,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    entry.humanDescription,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                  ),
                  trailing: Text(
                    _formatDate(entry.createdAt),
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
                  ),
                );
              },
            ),
    );
  }
}
