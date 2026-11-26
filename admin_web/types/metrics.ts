/**
 * Strongly typed metrics models matching Flutter dashboard
 */

export interface HeadlineKpis {
  totalStaff: number;
  activeStaff: number;
  pendingStaff: number;
  revokedStaff: number;
  activeDelta: number;
  pendingDelta: number;
  revokedDelta: number;
  totalDelta: number;
}

export interface SeatUsage {
  storedSeatCount: number;
  seatLimit: number;
  trueSeatCount: number;
  isOutOfSync: boolean;
  ratio: number;
  remainingSeats: number;
}

export interface OnboardingFunnel {
  totalInvited: number;
  codePending: number;
  joined: number;
  expired: number;
  conversionRate: number;
}

export interface DepartmentHeadcountItem {
  deptId: string;
  name: string;
  count: number;
}

export interface DepartmentBreakdown {
  departments: DepartmentHeadcountItem[];
  unassignedCount: number;
}

export interface RoleDistribution {
  adminCount: number;
  leadCount: number;
  employeeCount: number;
  total: number;
}

export interface WeeklyJoinBucket {
  weekStart: string; // ISO date
  weekEnd: string;
  label: string; // e.g. "Sep 16"
  count: number;
}

export interface JoinsOverTime {
  requestedWeeks: number;
  weeklyBuckets: WeeklyJoinBucket[];
  excludedNoJoinDateCount: number;
}

export interface GroupsOverview {
  activeDepartments: number;
  archivedDepartments: number;
  activeProjects: number;
  archivedProjects: number;
}

export type NeedsAttentionType =
  | 'expiringCode'
  | 'staleInvite'
  | 'departmentNoHead'
  | 'departmentZeroStaff'
  | 'projectRevokedOwner';

export interface NeedsAttentionItem {
  id: string;
  title: string;
  subtitle: string;
  type: NeedsAttentionType;
  route: string;
}

export interface NoticesOversight {
  publishedCount: number;
  urgentCount: number;
  policyCount: number;
  latestPolicyNoticeId?: string;
  latestPolicyAuthor?: string;
  latestPolicyVersion?: number;
  latestPolicyAckRate?: number;
  latestPolicyAckCount: number;
  activeMembersCount: number;
}

export interface PresenceEngagement {
  activeInLast7Days: number | null;
  isPrivacyDisabled: boolean;
}

export interface DashboardBundle {
  headlineKpis: HeadlineKpis;
  seatUsage: SeatUsage;
  funnel: OnboardingFunnel;
  departmentBreakdown: DepartmentBreakdown;
  roleDistribution: RoleDistribution;
  joinsOverTime: JoinsOverTime;
  groupsOverview: GroupsOverview;
  needsAttention: NeedsAttentionItem[];
  noticesOversight: NoticesOversight;
  presenceEngagement: PresenceEngagement;
  recentActivity: any[];
  lastFetched: Date;
}

