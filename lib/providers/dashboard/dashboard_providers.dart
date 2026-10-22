import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audit_entry.dart';
import '../../models/dashboard_metrics_models.dart';
import '../../models/firm.dart';
import '../../services/audit_service.dart';
import '../../services/dashboard_metrics_repository.dart';
import '../firm/providers.dart';

/// Complete bundle of all dashboard metrics loaded in a single coordinated query pass.
class DashboardBundle {
  final HeadlineKpiData headlineKpis;
  final SeatUsageData seatUsage;
  final OnboardingFunnelData funnel;
  final DepartmentBreakdownData departmentBreakdown;
  final RoleDistributionData roleDistribution;
  final JoinsOverTimeData joinsOverTime;
  final GroupsOverviewData groupsOverview;
  final List<NeedsAttentionItem> needsAttention;
  final NoticesOversightData noticesOversight;
  final PresenceEngagementData presenceEngagement;
  final List<AuditEntry> recentActivity;
  final DateTime lastFetched;

  const DashboardBundle({
    required this.headlineKpis,
    required this.seatUsage,
    required this.funnel,
    required this.departmentBreakdown,
    required this.roleDistribution,
    required this.joinsOverTime,
    required this.groupsOverview,
    required this.needsAttention,
    required this.noticesOversight,
    required this.presenceEngagement,
    required this.recentActivity,
    required this.lastFetched,
  });

  bool get isStale => DateTime.now().difference(lastFetched) > const Duration(minutes: 5);
}

/// Selected time horizon for the Joins Over Time chart (4, 8, or 12 weeks)
final joinsTimeframeWeeksProvider = StateProvider<int>((ref) => 8);

/// State notifier managing dashboard data loading, caching with 5-minute TTL,
/// and a 30-second throttled manual refresh.
class DashboardMetricsNotifier extends StateNotifier<AsyncValue<DashboardBundle>> {
  final Ref _ref;
  DateTime? _lastRefreshAttempt;
  static const Duration _throttleInterval = Duration(seconds: 30);
  static const Duration _cacheTtl = Duration(minutes: 5);

  DashboardMetricsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadDashboard();
  }

  /// Initial load or periodic refresh adhering to 5-minute TTL
  Future<void> loadDashboard({bool force = false}) async {
    final currentVal = state.asData?.value;
    final now = DateTime.now();

    // Cache hit: If not forcing and data is younger than TTL, retain current
    if (!force && currentVal != null && now.difference(currentVal.lastFetched) < _cacheTtl) {
      return;
    }

    await _executeFetch(now);
  }

  /// Throttled manual refresh callable by the user. Returns whether a fresh fetch was initiated.
  Future<bool> refreshDashboard({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastRefreshAttempt != null && now.difference(_lastRefreshAttempt!) < _throttleInterval) {
      debugPrint('[DashboardMetrics] Refresh throttled. Must wait 30s between queries.');
      return false;
    }

    _lastRefreshAttempt = now;
    await _executeFetch(now);
    return true;
  }

  Future<void> _executeFetch(DateTime fetchTime) async {
    final firm = _ref.read(currentFirmProvider);
    if (firm == null) {
      state = AsyncValue.error('No firm selected', StackTrace.current);
      return;
    }

    final repo = DashboardMetricsRepository.instance;
    final weeks = _ref.read(joinsTimeframeWeeksProvider);

    try {
      // 1. Fetch Headline KPIs first (provides active and invited counts for zero-cost reuse)
      final kpis = await repo.fetchHeadlineKpis(firm.firmId);

      // 2. Parallelize remaining metrics using precomputed active/invited staff counts
      final results = await Future.wait([
        repo.fetchSeatUsage(firm, precomputedActive: kpis.activeStaff, precomputedInvited: kpis.pendingStaff),
        repo.fetchOnboardingFunnel(firm.firmId),
        repo.fetchDepartmentBreakdown(firm.firmId, precomputedActiveStaff: kpis.activeStaff),
        repo.fetchRoleDistribution(firm.firmId),
        repo.fetchJoinsOverTime(firm.firmId, weeks: weeks),
        repo.fetchGroupsOverview(firm.firmId),
        repo.fetchNoticesOversight(firm.firmId, activeMembersCount: kpis.activeStaff),
        repo.fetchPresenceEngagement(firm.firmId, firm.showLastSeen),
        AuditService.instance.fetchRecentActivity(firm.firmId, limit: 10),
      ]);

      final seatUsage = results[0] as SeatUsageData;
      final funnel = results[1] as OnboardingFunnelData;
      final deptBreakdown = results[2] as DepartmentBreakdownData;
      final roleDist = results[3] as RoleDistributionData;
      final joins = results[4] as JoinsOverTimeData;
      final groups = results[5] as GroupsOverviewData;
      final notices = results[6] as NoticesOversightData;
      final presence = results[7] as PresenceEngagementData;
      final recentActivity = results[8] as List<AuditEntry>;

      // 3. Needs Attention uses department headcounts from breakdown
      final attentionItems = await repo.fetchNeedsAttention(
        firm.firmId,
        deptHeadcounts: deptBreakdown.departments,
      );

      final bundle = DashboardBundle(
        headlineKpis: kpis,
        seatUsage: seatUsage,
        funnel: funnel,
        departmentBreakdown: deptBreakdown,
        roleDistribution: roleDist,
        joinsOverTime: joins,
        groupsOverview: groups,
        needsAttention: attentionItems,
        noticesOversight: notices,
        presenceEngagement: presence,
        recentActivity: recentActivity,
        lastFetched: fetchTime,
      );

      state = AsyncValue.data(bundle);
    } catch (e, st) {
      debugPrint('[DashboardMetrics] Failed to load dashboard metrics: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Update the weeks timeframe for joins chart and re-fetch joins slice
  Future<void> setJoinsWeeks(int weeks) async {
    _ref.read(joinsTimeframeWeeksProvider.notifier).state = weeks;
    final firm = _ref.read(currentFirmProvider);
    final currentVal = state.asData?.value;
    if (firm == null || currentVal == null) return;

    try {
      final updatedJoins = await DashboardMetricsRepository.instance.fetchJoinsOverTime(firm.firmId, weeks: weeks);
      final updatedBundle = DashboardBundle(
        headlineKpis: currentVal.headlineKpis,
        seatUsage: currentVal.seatUsage,
        funnel: currentVal.funnel,
        departmentBreakdown: currentVal.departmentBreakdown,
        roleDistribution: currentVal.roleDistribution,
        joinsOverTime: updatedJoins,
        groupsOverview: currentVal.groupsOverview,
        needsAttention: currentVal.needsAttention,
        noticesOversight: currentVal.noticesOversight,
        presenceEngagement: currentVal.presenceEngagement,
        recentActivity: currentVal.recentActivity,
        lastFetched: currentVal.lastFetched,
      );
      state = AsyncValue.data(updatedBundle);
    } catch (e) {
      debugPrint('[DashboardMetrics] Failed to update joins timeframe: $e');
    }
  }
}

/// Primary bundle provider
final dashboardMetricsProvider =
    StateNotifierProvider<DashboardMetricsNotifier, AsyncValue<DashboardBundle>>((ref) {
  // Listen for changes in the active firm and reload if firm changes
  ref.listen<Firm?>(currentFirmProvider, (prev, next) {
    if (prev?.firmId != next?.firmId) {
      ref.notifier.loadDashboard(force: true);
    }
  });
  return DashboardMetricsNotifier(ref);
});

// Granular selector providers for individual dashboard components
final headlineKpisProvider = Provider<AsyncValue<HeadlineKpiData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.headlineKpis);
});

final seatUsageProvider = Provider<AsyncValue<SeatUsageData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.seatUsage);
});

final onboardingFunnelProvider = Provider<AsyncValue<OnboardingFunnelData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.funnel);
});

final departmentBreakdownProvider = Provider<AsyncValue<DepartmentBreakdownData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.departmentBreakdown);
});

final roleDistributionProvider = Provider<AsyncValue<RoleDistributionData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.roleDistribution);
});

final joinsOverTimeProvider = Provider<AsyncValue<JoinsOverTimeData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.joinsOverTime);
});

final groupsOverviewProvider = Provider<AsyncValue<GroupsOverviewData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.groupsOverview);
});

final needsAttentionProvider = Provider<AsyncValue<List<NeedsAttentionItem>>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.needsAttention);
});

final noticesOversightProvider = Provider<AsyncValue<NoticesOversightData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.noticesOversight);
});

final presenceEngagementProvider = Provider<AsyncValue<PresenceEngagementData>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.presenceEngagement);
});

final recentActivityProvider = Provider<AsyncValue<List<AuditEntry>>>((ref) {
  return ref.watch(dashboardMetricsProvider).whenData((b) => b.recentActivity);
});
