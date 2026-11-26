/**
 * Single source of truth repository for all Firestore metrics on the Admin Dashboard.
 *
 * Implements:
 * 1. Strict READ-ONLY access via db-read-only wrapper.
 * 2. Parallel query batching via Promise.allSettled.
 * 3. Server-side getCountFromServer() aggregate queries for cost control.
 * 4. Zero whole-collection streaming and zero mock numbers.
 * 5. 100% parity with Flutter DashboardMetricsRepository.
 */

import { query, where, orderBy, limit, Timestamp } from "firebase/firestore";
import {
  readOnlyGetDoc,
  readOnlyGetDocs,
  readOnlyCount,
  getDocRef,
  getCollectionRef,
} from "../firebase/db-read-only";
import { getStartOfWeekLocal, getWeeklyIntervals } from "../format/date";
import { Firm } from "@/types/firestore";
import {
  HeadlineKpis,
  SeatUsage,
  OnboardingFunnel,
  DepartmentBreakdown,
  DepartmentHeadcountItem,
  RoleDistribution,
  JoinsOverTime,
  WeeklyJoinBucket,
  GroupsOverview,
  NeedsAttentionItem,
  NoticesOversight,
  PresenceEngagement,
} from "@/types/metrics";

/**
 * 1. Headline KPIs: Total, Active, Pending, Revoked + Weekly Deltas
 */
export async function fetchHeadlineKpis(firmId: string): Promise<HeadlineKpis> {
  const membersCol = getCollectionRef("Firms", firmId, "members");
  const preApprovedCol = getCollectionRef("Firms", firmId, "PreApprovedStaff");
  const startOfWeek = Timestamp.fromDate(getStartOfWeekLocal(new Date()));

  try {
    const [
      activeSnap,
      pendingMembersSnap,
      revokedSnap,
      invitedPreApprovedSnap,
      activeDeltaSnap,
      pendingDeltaSnap,
      revokedDeltaSnap,
    ] = await Promise.all([
      // Base counts
      readOnlyCount(query(membersCol, where("status", "==", "active"))),
      readOnlyCount(query(membersCol, where("status", "==", "pending"))),
      readOnlyCount(query(membersCol, where("status", "==", "revoked"))),
      readOnlyCount(query(preApprovedCol, where("status", "==", "invited"))),
      // Deltas since Monday 00:00
      readOnlyCount(
        query(
          membersCol,
          where("status", "==", "active"),
          where("joinedAt", ">=", startOfWeek)
        )
      ),
      readOnlyCount(
        query(
          preApprovedCol,
          where("status", "==", "invited"),
          where("invitedAt", ">=", startOfWeek)
        )
      ),
      readOnlyCount(
        query(
          membersCol,
          where("status", "==", "revoked"),
          where("revokedAt", ">=", startOfWeek)
        )
      ),
    ]);

    const active = activeSnap;
    const pendingMembers = pendingMembersSnap;
    const revoked = revokedSnap;
    const invitedPreApproved = invitedPreApprovedSnap;

    const activeDelta = activeDeltaSnap;
    const pendingDelta = pendingDeltaSnap;
    const revokedDelta = revokedDeltaSnap;

    // Unify with OnboardingTab: Pending = pending approval members + invited pre-approved
    const pending = pendingMembers + invitedPreApproved;
    const total = active + pending + revoked;
    const totalDelta = activeDelta + pendingDelta;

    return {
      totalStaff: total,
      activeStaff: active,
      pendingStaff: pending,
      revokedStaff: revoked,
      activeDelta,
      pendingDelta,
      revokedDelta,
      totalDelta,
    };
  } catch (err) {
    console.error("[fetchHeadlineKpis] Error:", err);
    return {
      totalStaff: 0,
      activeStaff: 0,
      pendingStaff: 0,
      revokedStaff: 0,
      activeDelta: 0,
      pendingDelta: 0,
      revokedDelta: 0,
      totalDelta: 0,
    };
  }
}

/**
 * 2. True Seat Usage vs Stored Counter
 */
export async function fetchSeatUsage(
  firm: Firm,
  precomputedActive?: number,
  precomputedInvited?: number
): Promise<SeatUsage> {
  let active = precomputedActive;
  let invited = precomputedInvited;

  if (active === undefined || invited === undefined) {
    try {
      const membersCol = getCollectionRef("Firms", firm.firmId, "members");
      const preApprovedCol = getCollectionRef("Firms", firm.firmId, "PreApprovedStaff");
      const [a, i] = await Promise.all([
        readOnlyCount(query(membersCol, where("status", "==", "active"))),
        readOnlyCount(query(preApprovedCol, where("status", "==", "invited"))),
      ]);
      active = a;
      invited = i;
    } catch {
      active = 0;
      invited = 0;
    }
  }

  const trueSeats = active + invited;
  const isOutOfSync = trueSeats !== firm.seatCount;
  const remaining = Math.max(0, firm.seatLimit - trueSeats);
  const ratio = Math.min(1.0, trueSeats / (firm.seatLimit > 0 ? firm.seatLimit : 1));

  return {
    storedSeatCount: firm.seatCount,
    seatLimit: firm.seatLimit,
    trueSeatCount: trueSeats,
    isOutOfSync,
    ratio,
    remainingSeats: remaining,
  };
}

/**
 * 3. Onboarding Funnel (Invited -> Code Pending -> Joined + Expired)
 */
export async function fetchOnboardingFunnel(firmId: string): Promise<OnboardingFunnel> {
  const preApprovedCol = getCollectionRef("Firms", firmId, "PreApprovedStaff");
  const now = Timestamp.now();

  try {
    const [totalInvited, joined, codePending, expired] = await Promise.all([
      readOnlyCount(query(preApprovedCol)),
      readOnlyCount(query(preApprovedCol, where("status", "==", "joined"))),
      readOnlyCount(
        query(
          preApprovedCol,
          where("status", "==", "invited"),
          where("codeExpiresAt", ">=", now)
        )
      ),
      readOnlyCount(
        query(
          preApprovedCol,
          where("status", "==", "invited"),
          where("codeExpiresAt", "<", now)
        )
      ),
    ]);

    const conversionRate = totalInvited > 0 ? (joined / totalInvited) * 100 : 0;

    return {
      totalInvited,
      codePending,
      joined,
      expired,
      conversionRate,
    };
  } catch (err) {
    console.error("[fetchOnboardingFunnel] Error:", err);
    return {
      totalInvited: 0,
      codePending: 0,
      joined: 0,
      expired: 0,
      conversionRate: 0,
    };
  }
}

/**
 * 4. Department Headcount Breakdown (Includes Unassigned Active Staff)
 */
export async function fetchDepartmentBreakdown(
  firmId: string,
  precomputedActiveStaff?: number
): Promise<DepartmentBreakdown> {
  const deptsCol = getCollectionRef("Firms", firmId, "departments");
  const membersCol = getCollectionRef("Firms", firmId, "members");

  try {
    // Limit to 20 departments for cost safety
    const deptsSnap = await readOnlyGetDocs(
      query(deptsCol, where("status", "==", "active"), limit(20))
    );

    const items: DepartmentHeadcountItem[] = [];
    let assignedTotal = 0;

    if (!deptsSnap.empty) {
      const countPromises = deptsSnap.docs.map((d) =>
        readOnlyCount(
          query(
            membersCol,
            where("departmentId", "==", d.id),
            where("status", "==", "active")
          )
        )
      );

      const countResults = await Promise.all(countPromises);

      for (let i = 0; i < deptsSnap.docs.length; i++) {
        const doc = deptsSnap.docs[i];
        const name = (doc.data()?.name as string) || "Department";
        const count = countResults[i];
        assignedTotal += count;
        items.push({ deptId: doc.id, name, count });
      }
    }

    let totalActive = precomputedActiveStaff;
    if (totalActive === undefined) {
      totalActive = await readOnlyCount(query(membersCol, where("status", "==", "active")));
    }

    const unassigned = Math.max(0, totalActive - assignedTotal);

    return {
      departments: items,
      unassignedCount: unassigned,
    };
  } catch (err) {
    console.error("[fetchDepartmentBreakdown] Error:", err);
    return { departments: [], unassignedCount: 0 };
  }
}

/**
 * 5. Role Distribution (Admin, Lead, Employee among active members)
 */
export async function fetchRoleDistribution(firmId: string): Promise<RoleDistribution> {
  const membersCol = getCollectionRef("Firms", firmId, "members");

  try {
    const [adminCount, leadCount, employeeCount] = await Promise.all([
      readOnlyCount(query(membersCol, where("status", "==", "active"), where("role", "==", "admin"))),
      readOnlyCount(query(membersCol, where("status", "==", "active"), where("role", "==", "lead"))),
      readOnlyCount(query(membersCol, where("status", "==", "active"), where("role", "==", "employee"))),
    ]);

    return {
      adminCount,
      leadCount,
      employeeCount,
      total: adminCount + leadCount + employeeCount,
    };
  } catch (err) {
    console.error("[fetchRoleDistribution] Error:", err);
    return { adminCount: 0, leadCount: 0, employeeCount: 0, total: 0 };
  }
}

/**
 * 6. Joins Over Time: New members per week (4, 8, or 12 weeks)
 */
export async function fetchJoinsOverTime(
  firmId: string,
  weeks: number = 8
): Promise<JoinsOverTime> {
  const membersCol = getCollectionRef("Firms", firmId, "members");
  const intervals = getWeeklyIntervals(weeks);

  try {
    const countPromises = intervals.map(({ weekStart, weekEnd }) =>
      readOnlyCount(
        query(
          membersCol,
          where("status", "==", "active"),
          where("joinedAt", ">=", Timestamp.fromDate(weekStart)),
          where("joinedAt", "<", Timestamp.fromDate(weekEnd))
        )
      )
    );

    const counts = await Promise.all(countPromises);
    let totalInBuckets = 0;

    const buckets: WeeklyJoinBucket[] = intervals.map((interval, i) => {
      const c = counts[i];
      totalInBuckets += c;
      return {
        weekStart: interval.weekStart.toISOString(),
        weekEnd: interval.weekEnd.toISOString(),
        label: interval.label,
        count: c,
      };
    });

    // Check total active & older than window to calculate documents lacking `joinedAt`
    const totalActiveSnap = await readOnlyCount(query(membersCol, where("status", "==", "active")));
    const oldestIntervalStart = intervals[0].weekStart;
    const olderSnap = await readOnlyCount(
      query(
        membersCol,
        where("status", "==", "active"),
        where("joinedAt", "<", Timestamp.fromDate(oldestIntervalStart))
      )
    );

    const excluded = Math.max(0, totalActiveSnap - (totalInBuckets + olderSnap));

    return {
      requestedWeeks: weeks,
      weeklyBuckets: buckets,
      excludedNoJoinDateCount: excluded,
    };
  } catch (err) {
    console.error("[fetchJoinsOverTime] Error:", err);
    return {
      requestedWeeks: weeks,
      weeklyBuckets: [],
      excludedNoJoinDateCount: 0,
    };
  }
}

/**
 * 7. Groups Overview (Active & Archived Departments and Projects)
 */
export async function fetchGroupsOverview(firmId: string): Promise<GroupsOverview> {
  const deptsCol = getCollectionRef("Firms", firmId, "departments");
  const projectsCol = getCollectionRef("Firms", firmId, "projects");

  try {
    const [actDepts, archDepts, actProjs, archProjs] = await Promise.all([
      readOnlyCount(query(deptsCol, where("status", "==", "active"))),
      readOnlyCount(query(deptsCol, where("status", "==", "archived"))),
      readOnlyCount(query(projectsCol, where("status", "==", "active"))),
      readOnlyCount(query(projectsCol, where("status", "==", "archived"))),
    ]);

    return {
      activeDepartments: actDepts,
      archivedDepartments: archDepts,
      activeProjects: actProjs,
      archivedProjects: archProjs,
    };
  } catch (err) {
    console.error("[fetchGroupsOverview] Error:", err);
    return {
      activeDepartments: 0,
      archivedDepartments: 0,
      activeProjects: 0,
      archivedProjects: 0,
    };
  }
}

/**
 * 8. Needs Attention Panel Items
 */
export async function fetchNeedsAttention(
  firmId: string,
  deptHeadcounts?: DepartmentHeadcountItem[]
): Promise<NeedsAttentionItem[]> {
  const items: NeedsAttentionItem[] = [];
  const preApprovedCol = getCollectionRef("Firms", firmId, "PreApprovedStaff");
  const deptsCol = getCollectionRef("Firms", firmId, "departments");
  const projectsCol = getCollectionRef("Firms", firmId, "projects");
  const membersCol = getCollectionRef("Firms", firmId, "members");

  const now = new Date();
  const fiveMinFromNow = new Date(now.getTime() + 5 * 60 * 1000);
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  try {
    // 1. Invites expiring soon (< 5 minutes)
    const expiringSnap = await readOnlyGetDocs(
      query(
        preApprovedCol,
        where("status", "==", "invited"),
        where("codeExpiresAt", ">", Timestamp.fromDate(now)),
        where("codeExpiresAt", "<", Timestamp.fromDate(fiveMinFromNow)),
        limit(5)
      )
    );

    for (const d of expiringSnap.docs) {
      const email = d.data().email || "Staff";
      items.push({
        id: `exp_${d.id}`,
        title: `Expiring code: ${email}`,
        subtitle: "Staff code will expire soon. Regenerate or share before expiration.",
        type: "expiringCode",
        route: "/admin/onboarding?filter=invited",
      });
    }

    // 2. Stale invites pending > 7 days
    const staleSnap = await readOnlyGetDocs(
      query(
        preApprovedCol,
        where("status", "==", "invited"),
        where("invitedAt", "<", Timestamp.fromDate(sevenDaysAgo)),
        limit(5)
      )
    );

    for (const d of staleSnap.docs) {
      const email = d.data().email || "Staff";
      items.push({
        id: `stale_${d.id}`,
        title: `Unclaimed invite: ${email}`,
        subtitle: "Invited over 7 days ago and has not joined.",
        type: "staleInvite",
        route: "/admin/onboarding?filter=invited",
      });
    }

    // 3. Departments without a head or with zero staff
    const deptsSnap = await readOnlyGetDocs(
      query(deptsCol, where("status", "==", "active"), limit(15))
    );

    const deptCountMap = new Map<string, number>();
    (deptHeadcounts || []).forEach((d) => deptCountMap.set(d.deptId, d.count));

    for (const d of deptsSnap.docs) {
      const name = d.data().name || "Department";
      const headUid = d.data().headUid;

      if (!headUid || headUid.trim().length === 0) {
        items.push({
          id: `nohead_${d.id}`,
          title: `${name} needs a Department Head`,
          subtitle: "Assign a lead to enable department broadcasts and oversight.",
          type: "departmentNoHead",
          route: "/admin/notices?sub=departments",
        });
      }

      const staffCount = deptCountMap.get(d.id);
      if (staffCount === 0) {
        items.push({
          id: `zerostaff_${d.id}`,
          title: `${name} has zero active staff`,
          subtitle: "Assign employees to this department from Onboarding.",
          type: "departmentZeroStaff",
          route: "/admin/onboarding",
        });
      }
    }

    // 4. Project groups whose owner is revoked
    const projsSnap = await readOnlyGetDocs(
      query(projectsCol, where("status", "==", "active"), limit(15))
    );

    for (const d of projsSnap.docs) {
      const ownerUid = d.data().ownerUid;
      const projName = d.data().name || "Project";
      if (ownerUid) {
        const memberSnap = await readOnlyGetDoc(
          getDocRef("Firms", firmId, "members", ownerUid)
        );
        if (memberSnap.exists() && memberSnap.data().status === "revoked") {
          items.push({
            id: `revoked_owner_${d.id}`,
            title: `${projName} owner access is revoked`,
            subtitle: "Reassign leadership to an active lead or admin.",
            type: "projectRevokedOwner",
            route: "/admin/notices?sub=projects",
          });
        }
      }
    }

    return items;
  } catch (err) {
    console.error("[fetchNeedsAttention] Error:", err);
    return items;
  }
}

/**
 * 9. Notices Oversight & Policy Acknowledgement Rate (Metadata only)
 */
export async function fetchNoticesOversight(
  firmId: string,
  activeMembersCount?: number
): Promise<NoticesOversight> {
  const noticeIndexCol = getCollectionRef("Firms", firmId, "noticeIndex");

  try {
    const [publishedCount, urgentCount, policyCount, latestPolicySnap] = await Promise.all([
      readOnlyCount(query(noticeIndexCol, where("status", "==", "published"))),
      readOnlyCount(
        query(
          noticeIndexCol,
          where("status", "==", "published"),
          where("type", "==", "urgent")
        )
      ),
      readOnlyCount(
        query(
          noticeIndexCol,
          where("status", "==", "published"),
          where("type", "==", "policy")
        )
      ),
      readOnlyGetDocs(
        query(
          noticeIndexCol,
          where("status", "==", "published"),
          where("type", "==", "policy"),
          orderBy("createdAt", "desc"),
          limit(1)
        )
      ),
    ]);

    let latestPolicyNoticeId: string | undefined;
    let latestPolicyAuthor: string | undefined;
    let latestPolicyVersion: number | undefined;
    let latestPolicyAckCount = 0;
    let latestPolicyAckRate: number | undefined;

    if (!latestPolicySnap.empty) {
      const d = latestPolicySnap.docs[0];
      latestPolicyNoticeId = d.id;
      latestPolicyAuthor = d.data().authorName;
      latestPolicyVersion = Number(d.data().version) || 1;

      // Query policy acks subcollection
      const acksCol = getCollectionRef("Firms", firmId, "notices", latestPolicyNoticeId, "acks");
      latestPolicyAckCount = await readOnlyCount(
        query(acksCol, where("version", "==", latestPolicyVersion))
      );

      const activeTotal = activeMembersCount || 1;
      latestPolicyAckRate = Math.min(100, Math.max(0, (latestPolicyAckCount / activeTotal) * 100));
    }

    return {
      publishedCount,
      urgentCount,
      policyCount,
      latestPolicyNoticeId,
      latestPolicyAuthor,
      latestPolicyVersion,
      latestPolicyAckRate,
      latestPolicyAckCount,
      activeMembersCount: activeMembersCount || 0,
    };
  } catch (err) {
    console.error("[fetchNoticesOversight] Error:", err);
    return {
      publishedCount: 0,
      urgentCount: 0,
      policyCount: 0,
      latestPolicyAckCount: 0,
      activeMembersCount: 0,
    };
  }
}

/**
 * 10. Presence Engagement: Active in last 7 days (Firm-level aggregate only)
 */
export async function fetchPresenceEngagement(
  firmId: string,
  showLastSeen: boolean
): Promise<PresenceEngagement> {
  if (!showLastSeen) {
    return { activeInLast7Days: null, isPrivacyDisabled: true };
  }

  try {
    const presenceCol = getCollectionRef("Firms", firmId, "presence");
    const sevenDaysAgo = Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );

    const count = await readOnlyCount(
      query(presenceCol, where("lastSeenAt", ">=", sevenDaysAgo))
    );

    return { activeInLast7Days: count, isPrivacyDisabled: false };
  } catch (err) {
    console.error("[fetchPresenceEngagement] Error:", err);
    return { activeInLast7Days: null, isPrivacyDisabled: false };
  }
}

/**
 * 11. Recent Activity: Latest 10 audit log entries
 */
export async function fetchRecentActivity(firmId: string, limitCount: number = 10) {
  try {
    const auditCol = getCollectionRef("Firms", firmId, "auditLog");
    const snap = await readOnlyGetDocs(
      query(auditCol, orderBy("createdAt", "desc"), limit(limitCount))
    );
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (err) {
    console.error("[fetchRecentActivity] Error:", err);
    return [];
  }
}

