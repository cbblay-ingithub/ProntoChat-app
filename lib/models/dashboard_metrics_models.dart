/// Strongly-typed models for all real-data Firestore metrics on the Admin Dashboard.

class HeadlineKpiData {
  final int totalStaff;
  final int activeStaff;
  final int pendingStaff;
  final int revokedStaff;
  final int activeDelta;
  final int pendingDelta;
  final int revokedDelta;

  const HeadlineKpiData({
    required this.totalStaff,
    required this.activeStaff,
    required this.pendingStaff,
    required this.revokedStaff,
    required this.activeDelta,
    required this.pendingDelta,
    required this.revokedDelta,
  });

  const HeadlineKpiData.empty()
      : totalStaff = 0,
        activeStaff = 0,
        pendingStaff = 0,
        revokedStaff = 0,
        activeDelta = 0,
        pendingDelta = 0,
        revokedDelta = 0;
}

class SeatUsageData {
  final int storedSeatCount;
  final int seatLimit;
  final int trueSeatCount;
  final bool isOutOfSync;

  const SeatUsageData({
    required this.storedSeatCount,
    required this.seatLimit,
    required this.trueSeatCount,
    required this.isOutOfSync,
  });

  double get ratio => (trueSeatCount / (seatLimit > 0 ? seatLimit : 1)).clamp(0.0, 1.0);
  int get remainingSeats => (seatLimit - trueSeatCount).clamp(0, seatLimit);
}

class OnboardingFunnelData {
  final int totalInvited;
  final int codePending;
  final int joined;
  final int expired;
  final double conversionRate;

  const OnboardingFunnelData({
    required this.totalInvited,
    required this.codePending,
    required this.joined,
    required this.expired,
    required this.conversionRate,
  });

  bool get hasData => totalInvited > 0 || codePending > 0 || joined > 0;
}

class DepartmentHeadcountItem {
  final String deptId;
  final String name;
  final int count;

  const DepartmentHeadcountItem({
    required this.deptId,
    required this.name,
    required this.count,
  });
}

class DepartmentBreakdownData {
  final List<DepartmentHeadcountItem> departments;
  final int unassignedCount;

  const DepartmentBreakdownData({
    required this.departments,
    required this.unassignedCount,
  });

  bool get hasData => departments.any((d) => d.count > 0) || unassignedCount > 0;
}

class RoleDistributionData {
  final int adminCount;
  final int leadCount;
  final int employeeCount;

  const RoleDistributionData({
    required this.adminCount,
    required this.leadCount,
    required this.employeeCount,
  });

  int get total => adminCount + leadCount + employeeCount;
  bool get hasData => total > 0;
}

class WeeklyJoinBucket {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int count;

  const WeeklyJoinBucket({
    required this.weekStart,
    required this.weekEnd,
    required this.count,
  });
}

class JoinsOverTimeData {
  final int requestedWeeks;
  final List<WeeklyJoinBucket> weeklyBuckets;
  final int excludedNoJoinDateCount;

  const JoinsOverTimeData({
    required this.requestedWeeks,
    required this.weeklyBuckets,
    required this.excludedNoJoinDateCount,
  });

  bool get hasData => weeklyBuckets.any((b) => b.count > 0);
}

class GroupsOverviewData {
  final int activeDepartments;
  final int archivedDepartments;
  final int activeProjects;
  final int archivedProjects;

  const GroupsOverviewData({
    required this.activeDepartments,
    required this.archivedDepartments,
    required this.activeProjects,
    required this.archivedProjects,
  });
}

enum NeedsAttentionType {
  expiringCode,
  staleInvite,
  departmentNoHead,
  departmentZeroStaff,
  projectRevokedOwner,
}

class NeedsAttentionItem {
  final String id;
  final String title;
  final String subtitle;
  final NeedsAttentionType type;
  final String route;

  const NeedsAttentionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.route,
  });
}

class NoticesOversightData {
  final int publishedCount;
  final int urgentCount;
  final int policyCount;
  final String? latestPolicyNoticeId;
  final String? latestPolicyAuthor;
  final int? latestPolicyVersion;
  final double? latestPolicyAckRate;
  final int latestPolicyAckCount;
  final int activeMembersCount;

  const NoticesOversightData({
    required this.publishedCount,
    required this.urgentCount,
    required this.policyCount,
    this.latestPolicyNoticeId,
    this.latestPolicyAuthor,
    this.latestPolicyVersion,
    this.latestPolicyAckRate,
    this.latestPolicyAckCount = 0,
    this.activeMembersCount = 0,
  });
}

class PresenceEngagementData {
  final int? activeInLast7Days;
  final bool isPrivacyDisabled;

  const PresenceEngagementData({
    this.activeInLast7Days,
    required this.isPrivacyDisabled,
  });
}
