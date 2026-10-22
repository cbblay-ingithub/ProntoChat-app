import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/dashboard_metrics_models.dart';
import '../models/firm.dart';

/// Single source of truth repository for all Firestore metrics on the Admin Dashboard.
///
/// Designed with cost control, parallel execution, zero full-collection streaming,
/// and exact status parity with the OnboardingTab filters.
class DashboardMetricsRepository {
  DashboardMetricsRepository._internal();
  static final DashboardMetricsRepository instance = DashboardMetricsRepository._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Helper to get Monday 00:00:00 local time for the current week
  static DateTime getStartOfWeekLocal(DateTime now) {
    final local = now.toLocal();
    final daysToSubtract = (local.weekday - DateTime.monday) % 7;
    final monday = local.subtract(Duration(days: daysToSubtract));
    return DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
  }

  /// 1. Headline KPIs: Total, Active, Pending, Revoked + Weekly Deltas
  Future<HeadlineKpiData> fetchHeadlineKpis(String firmId) async {
    final membersCol = _db.collection('Firms').doc(firmId).collection('members');
    final preApprovedCol = _db.collection('Firms').doc(firmId).collection('PreApprovedStaff');
    final startOfWeek = Timestamp.fromDate(getStartOfWeekLocal(DateTime.now()));

    try {
      final results = await Future.wait([
        // Base counts
        membersCol.where('status', isEqualTo: 'active').count().get(), // 0
        membersCol.where('status', isEqualTo: 'pending').count().get(), // 1
        membersCol.where('status', isEqualTo: 'revoked').count().get(), // 2
        preApprovedCol.where('status', isEqualTo: 'invited').count().get(), // 3
        // Deltas since Monday 00:00
        membersCol
            .where('status', isEqualTo: 'active')
            .where('joinedAt', isGreaterThanOrEqualTo: startOfWeek)
            .count()
            .get(), // 4
        preApprovedCol
            .where('status', isEqualTo: 'invited')
            .where('invitedAt', isGreaterThanOrEqualTo: startOfWeek)
            .count()
            .get(), // 5
        membersCol
            .where('status', isEqualTo: 'revoked')
            .where('revokedAt', isGreaterThanOrEqualTo: startOfWeek)
            .count()
            .get(), // 6
      ]);

      final active = results[0].count ?? 0;
      final pendingMembers = results[1].count ?? 0;
      final revoked = results[2].count ?? 0;
      final invitedPreApproved = results[3].count ?? 0;

      final activeDelta = results[4].count ?? 0;
      final pendingDelta = (results[5].count ?? 0);
      final revokedDelta = results[6].count ?? 0;

      // Unify with OnboardingTab: Pending = pending approval members + invited pre-approved
      final pending = pendingMembers + invitedPreApproved;
      final total = active + pending + revoked;

      return HeadlineKpiData(
        totalStaff: total,
        activeStaff: active,
        pendingStaff: pending,
        revokedStaff: revoked,
        activeDelta: activeDelta,
        pendingDelta: pendingDelta,
        revokedDelta: revokedDelta,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching headline KPIs: $e');
      return const HeadlineKpiData.empty();
    }
  }

  /// 2. True Seat Usage vs Stored Counter
  Future<SeatUsageData> fetchSeatUsage(
    Firm firm, {
    int? precomputedActive,
    int? precomputedInvited,
  }) async {
    try {
      int active = precomputedActive ?? 0;
      int invited = precomputedInvited ?? 0;

      if (precomputedActive == null || precomputedInvited == null) {
        final membersCol = _db.collection('Firms').doc(firm.firmId).collection('members');
        final preApprovedCol = _db.collection('Firms').doc(firm.firmId).collection('PreApprovedStaff');

        final results = await Future.wait([
          membersCol.where('status', isEqualTo: 'active').count().get(),
          preApprovedCol.where('status', isEqualTo: 'invited').count().get(),
        ]);
        active = results[0].count ?? 0;
        invited = results[1].count ?? 0;
      }

      final trueSeats = active + invited;
      final isOutOfSync = trueSeats != firm.seatCount;

      return SeatUsageData(
        storedSeatCount: firm.seatCount,
        seatLimit: firm.seatLimit,
        trueSeatCount: trueSeats,
        isOutOfSync: isOutOfSync,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching seat usage: $e');
      return SeatUsageData(
        storedSeatCount: firm.seatCount,
        seatLimit: firm.seatLimit,
        trueSeatCount: firm.seatCount,
        isOutOfSync: false,
      );
    }
  }

  /// 3. Onboarding Funnel (Invited -> Code Pending -> Joined + Expired)
  Future<OnboardingFunnelData> fetchOnboardingFunnel(String firmId) async {
    final preApprovedCol = _db.collection('Firms').doc(firmId).collection('PreApprovedStaff');
    final now = Timestamp.now();

    try {
      final results = await Future.wait([
        preApprovedCol.count().get(), // 0: total ever invited
        preApprovedCol.where('status', isEqualTo: 'joined').count().get(), // 1: successfully joined
        preApprovedCol
            .where('status', isEqualTo: 'invited')
            .where('codeExpiresAt', isGreaterThanOrEqualTo: now)
            .count()
            .get(), // 2: valid code pending
        preApprovedCol
            .where('status', isEqualTo: 'invited')
            .where('codeExpiresAt', isLessThan: now)
            .count()
            .get(), // 3: expired / unclaimed
      ]);

      final totalInvited = results[0].count ?? 0;
      final joined = results[1].count ?? 0;
      final codePending = results[2].count ?? 0;
      final expired = results[3].count ?? 0;

      final conversionRate = totalInvited > 0 ? (joined / totalInvited) * 100.0 : 0.0;

      return OnboardingFunnelData(
        totalInvited: totalInvited,
        codePending: codePending,
        joined: joined,
        expired: expired,
        conversionRate: conversionRate,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching onboarding funnel: $e');
      return const OnboardingFunnelData(
        totalInvited: 0,
        codePending: 0,
        joined: 0,
        expired: 0,
        conversionRate: 0.0,
      );
    }
  }

  /// 4. Department Headcount Breakdown (Includes Unassigned Active Staff)
  Future<DepartmentBreakdownData> fetchDepartmentBreakdown(
    String firmId, {
    int? precomputedActiveStaff,
  }) async {
    final deptsCol = _db.collection('Firms').doc(firmId).collection('departments');
    final membersCol = _db.collection('Firms').doc(firmId).collection('members');

    try {
      // 1. Fetch active departments (bounded to 20 for cost safety)
      final deptsSnap = await deptsCol.where('status', isEqualTo: 'active').limit(20).get();

      final List<DepartmentHeadcountItem> items = [];
      int assignedTotal = 0;

      if (deptsSnap.docs.isNotEmpty) {
        // Parallel count per department
        final countFutures = deptsSnap.docs.map((doc) {
          return membersCol
              .where('departmentId', isEqualTo: doc.id)
              .where('status', isEqualTo: 'active')
              .count()
              .get();
        }).toList();

        final countResults = await Future.wait(countFutures);

        for (int i = 0; i < deptsSnap.docs.length; i++) {
          final doc = deptsSnap.docs[i];
          final name = (doc.data()['name'] as String?) ?? 'Department';
          final count = countResults[i].count ?? 0;
          assignedTotal += count;
          items.add(DepartmentHeadcountItem(deptId: doc.id, name: name, count: count));
        }
      }

      int totalActive = precomputedActiveStaff ?? 0;
      if (precomputedActiveStaff == null) {
        final totalActiveSnap = await membersCol.where('status', isEqualTo: 'active').count().get();
        totalActive = totalActiveSnap.count ?? 0;
      }

      final unassigned = (totalActive - assignedTotal).clamp(0, totalActive);

      return DepartmentBreakdownData(
        departments: items,
        unassignedCount: unassigned,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching department breakdown: $e');
      return const DepartmentBreakdownData(departments: [], unassignedCount: 0);
    }
  }

  /// 5. Role Distribution (Admin, Lead, Employee among active members)
  Future<RoleDistributionData> fetchRoleDistribution(String firmId) async {
    final membersCol = _db.collection('Firms').doc(firmId).collection('members');

    try {
      final results = await Future.wait([
        membersCol.where('status', isEqualTo: 'active').where('role', isEqualTo: 'admin').count().get(),
        membersCol.where('status', isEqualTo: 'active').where('role', isEqualTo: 'lead').count().get(),
        membersCol.where('status', isEqualTo: 'active').where('role', isEqualTo: 'employee').count().get(),
      ]);

      return RoleDistributionData(
        adminCount: results[0].count ?? 0,
        leadCount: results[1].count ?? 0,
        employeeCount: results[2].count ?? 0,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching role distribution: $e');
      return const RoleDistributionData(adminCount: 0, leadCount: 0, employeeCount: 0);
    }
  }

  /// 6. Joins Over Time: New members per week (4, 8, or 12 weeks)
  Future<JoinsOverTimeData> fetchJoinsOverTime(String firmId, {int weeks = 8}) async {
    final membersCol = _db.collection('Firms').doc(firmId).collection('members');
    final now = DateTime.now();
    final startOfThisWeek = getStartOfWeekLocal(now);

    final List<WeeklyJoinBucket> buckets = [];
    final List<Future<AggregateQuerySnapshot>> countQueries = [];

    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = startOfThisWeek.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));

      countQueries.add(
        membersCol
            .where('status', isEqualTo: 'active')
            .where('joinedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
            .where('joinedAt', isLessThan: Timestamp.fromDate(weekEnd))
            .count()
            .get(),
      );
    }

    try {
      final results = await Future.wait(countQueries);

      int totalInBuckets = 0;
      for (int i = 0; i < weeks; i++) {
        final weekStart = startOfThisWeek.subtract(Duration(days: (weeks - 1 - i) * 7));
        final weekEnd = weekStart.add(const Duration(days: 7));
        final count = results[i].count ?? 0;
        totalInBuckets += count;

        buckets.add(WeeklyJoinBucket(
          weekStart: weekStart,
          weekEnd: weekEnd,
          count: count,
        ));
      }

      // Check total active to discover documents missing `joinedAt`
      final totalActiveSnap = await membersCol.where('status', isEqualTo: 'active').count().get();
      final totalActive = totalActiveSnap.count ?? 0;

      // Excluded are active records joined BEFORE the window OR lacking a joinedAt field
      final olderThanWindowSnap = await membersCol
          .where('status', isEqualTo: 'active')
          .where('joinedAt', isLessThan: Timestamp.fromDate(startOfThisWeek.subtract(Duration(days: (weeks - 1) * 7))))
          .count()
          .get();
      final olderCount = olderThanWindowSnap.count ?? 0;
      final excluded = (totalActive - (totalInBuckets + olderCount)).clamp(0, totalActive);

      return JoinsOverTimeData(
        requestedWeeks: weeks,
        weeklyBuckets: buckets,
        excludedNoJoinDateCount: excluded,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching joins over time: $e');
      return JoinsOverTimeData(
        requestedWeeks: weeks,
        weeklyBuckets: [],
        excludedNoJoinDateCount: 0,
      );
    }
  }

  /// 7. Groups Overview (Active & Archived Departments and Projects)
  Future<GroupsOverviewData> fetchGroupsOverview(String firmId) async {
    final deptsCol = _db.collection('Firms').doc(firmId).collection('departments');
    final projectsCol = _db.collection('Firms').doc(firmId).collection('projects');

    try {
      final results = await Future.wait([
        deptsCol.where('status', isEqualTo: 'active').count().get(),
        deptsCol.where('status', isEqualTo: 'archived').count().get(),
        projectsCol.where('status', isEqualTo: 'active').count().get(),
        projectsCol.where('status', isEqualTo: 'archived').count().get(),
      ]);

      return GroupsOverviewData(
        activeDepartments: results[0].count ?? 0,
        archivedDepartments: results[1].count ?? 0,
        activeProjects: results[2].count ?? 0,
        archivedProjects: results[3].count ?? 0,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching groups overview: $e');
      return const GroupsOverviewData(
        activeDepartments: 0,
        archivedDepartments: 0,
        activeProjects: 0,
        archivedProjects: 0,
      );
    }
  }

  /// 8. Needs Attention Panel Items
  Future<List<NeedsAttentionItem>> fetchNeedsAttention(
    String firmId, {
    List<DepartmentHeadcountItem>? deptHeadcounts,
  }) async {
    final List<NeedsAttentionItem> items = [];
    final preApprovedCol = _db.collection('Firms').doc(firmId).collection('PreApprovedStaff');
    final deptsCol = _db.collection('Firms').doc(firmId).collection('departments');
    final projectsCol = _db.collection('Firms').doc(firmId).collection('projects');
    final membersCol = _db.collection('Firms').doc(firmId).collection('members');

    final now = DateTime.now();

    try {
      // 1. Invites expiring soon (< 5 minutes)
      final expiringSnap = await preApprovedCol
          .where('status', isEqualTo: 'invited')
          .where('codeExpiresAt', isGreaterThan: Timestamp.now())
          .where('codeExpiresAt', isLessThan: Timestamp.fromDate(now.add(const Duration(minutes: 5))))
          .limit(5)
          .get();

      for (final doc in expiringSnap.docs) {
        final data = doc.data();
        final email = (data['email'] as String?) ?? 'Staff';
        items.add(NeedsAttentionItem(
          id: 'exp_${doc.id}',
          title: 'Expiring code: $email',
          subtitle: 'Staff code will expire soon. Regenerate or share before expiration.',
          type: NeedsAttentionType.expiringCode,
          route: '/admin/onboarding?filter=invited',
        ));
      }

      // 2. Stale invites pending > 7 days
      final staleThreshold = Timestamp.fromDate(now.subtract(const Duration(days: 7)));
      final staleSnap = await preApprovedCol
          .where('status', isEqualTo: 'invited')
          .where('invitedAt', isLessThan: staleThreshold)
          .limit(5)
          .get();

      for (final doc in staleSnap.docs) {
        final data = doc.data();
        final email = (data['email'] as String?) ?? 'Staff';
        items.add(NeedsAttentionItem(
          id: 'stale_${doc.id}',
          title: 'Unclaimed invite: $email',
          subtitle: 'Invited over 7 days ago and has not joined.',
          type: NeedsAttentionType.staleInvite,
          route: '/admin/onboarding?filter=invited',
        ));
      }

      // 3. Departments without a head or with zero staff
      final deptsSnap = await deptsCol.where('status', isEqualTo: 'active').limit(15).get();
      final deptCountMap = {for (final d in deptHeadcounts ?? <DepartmentHeadcountItem>[]) d.deptId: d.count};

      for (final doc in deptsSnap.docs) {
        final data = doc.data();
        final name = (data['name'] as String?) ?? 'Department';
        final headUid = data['headUid'] as String?;

        if (headUid == null || headUid.trim().isEmpty) {
          items.add(NeedsAttentionItem(
            id: 'nohead_${doc.id}',
            title: '$name needs a Department Head',
            subtitle: 'Assign a lead to enable department broadcasts and oversight.',
            type: NeedsAttentionType.departmentNoHead,
            route: '/admin/notices?sub=departments',
          ));
        }

        final staffCount = deptCountMap[doc.id];
        if (staffCount == 0) {
          items.add(NeedsAttentionItem(
            id: 'zerostaff_${doc.id}',
            title: '$name has zero active staff',
            subtitle: 'Assign employees to this department from Onboarding.',
            type: NeedsAttentionType.departmentZeroStaff,
            route: '/admin/onboarding',
          ));
        }
      }

      // 4. Project groups whose owner is revoked
      final activeProjectsSnap = await projectsCol.where('status', isEqualTo: 'active').limit(15).get();
      for (final doc in activeProjectsSnap.docs) {
        final ownerUid = doc.data()['ownerUid'] as String?;
        final projName = (doc.data()['name'] as String?) ?? 'Project';
        if (ownerUid != null && ownerUid.isNotEmpty) {
          final memberDoc = await membersCol.doc(ownerUid).get();
          if (memberDoc.exists && memberDoc.data()?['status'] == 'revoked') {
            items.add(NeedsAttentionItem(
              id: 'revoked_owner_${doc.id}',
              title: '$projName owner access is revoked',
              subtitle: 'Reassign leadership to an active lead or admin.',
              type: NeedsAttentionType.projectRevokedOwner,
              route: '/admin/notices?sub=projects',
            ));
          }
        }
      }

      return items;
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching needs attention: $e');
      return items;
    }
  }

  /// 9. Notices Oversight & Policy Acknowledgement Rate (Metadata only)
  Future<NoticesOversightData> fetchNoticesOversight(String firmId, {int? activeMembersCount}) async {
    final noticeIndexCol = _db.collection('Firms').doc(firmId).collection('noticeIndex');

    try {
      final results = await Future.wait([
        noticeIndexCol.where('status', isEqualTo: 'published').count().get(), // 0
        noticeIndexCol.where('status', isEqualTo: 'published').where('type', isEqualTo: 'urgent').count().get(), // 1
        noticeIndexCol.where('status', isEqualTo: 'published').where('type', isEqualTo: 'policy').count().get(), // 2
        noticeIndexCol
            .where('status', isEqualTo: 'published')
            .where('type', isEqualTo: 'policy')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(), // 3
      ]);

      final publishedSnap = results[0] as AggregateQuerySnapshot;
      final urgentSnap = results[1] as AggregateQuerySnapshot;
      final policySnap = results[2] as AggregateQuerySnapshot;
      final latestPolicySnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

      final published = publishedSnap.count ?? 0;
      final urgent = urgentSnap.count ?? 0;
      final policy = policySnap.count ?? 0;

      String? latestPolicyId;
      String? latestPolicyAuthor;
      int? latestPolicyVersion;
      int latestPolicyAckCount = 0;
      double? latestPolicyAckRate;

      if (latestPolicySnap.docs.isNotEmpty) {
        final doc = latestPolicySnap.docs.first;
        latestPolicyId = doc.id;
        latestPolicyAuthor = doc.data()['authorName'] as String?;
        latestPolicyVersion = (doc.data()['version'] as num?)?.toInt() ?? 1;

        // Query policy acks subcollection
        final acksSnap = await _db
            .collection('Firms')
            .doc(firmId)
            .collection('notices')
            .doc(latestPolicyId)
            .collection('acks')
            .where('version', isEqualTo: latestPolicyVersion)
            .count()
            .get();

        latestPolicyAckCount = acksSnap.count ?? 0;
        final activeTotal = activeMembersCount ?? 1;
        latestPolicyAckRate = activeTotal > 0
            ? ((latestPolicyAckCount / activeTotal) * 100.0).clamp(0.0, 100.0)
            : 0.0;
      }

      return NoticesOversightData(
        publishedCount: published,
        urgentCount: urgent,
        policyCount: policy,
        latestPolicyNoticeId: latestPolicyId,
        latestPolicyAuthor: latestPolicyAuthor,
        latestPolicyVersion: latestPolicyVersion,
        latestPolicyAckRate: latestPolicyAckRate,
        latestPolicyAckCount: latestPolicyAckCount,
        activeMembersCount: activeMembersCount ?? 0,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching notices oversight: $e');
      return const NoticesOversightData(publishedCount: 0, urgentCount: 0, policyCount: 0);
    }
  }

  /// 10. Presence Engagement: Active in last 7 days (Firm-level aggregate only)
  Future<PresenceEngagementData> fetchPresenceEngagement(String firmId, bool showLastSeen) async {
    if (!showLastSeen) {
      return const PresenceEngagementData(activeInLast7Days: null, isPrivacyDisabled: true);
    }

    try {
      final presenceCol = _db.collection('Firms').doc(firmId).collection('presence');
      final sevenDaysAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));

      final countSnap = await presenceCol
          .where('lastSeenAt', isGreaterThanOrEqualTo: sevenDaysAgo)
          .count()
          .get();

      return PresenceEngagementData(
        activeInLast7Days: countSnap.count ?? 0,
        isPrivacyDisabled: false,
      );
    } catch (e) {
      debugPrint('[DashboardMetricsRepository] Error fetching presence engagement: $e');
      return const PresenceEngagementData(activeInLast7Days: null, isPrivacyDisabled: false);
    }
  }
}
