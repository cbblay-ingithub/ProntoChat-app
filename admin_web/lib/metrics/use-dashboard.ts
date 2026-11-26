/**
 * TanStack Query hook for Dashboard Metrics
 * Configured with:
 * - 5 minute staleTime
 * - No refetch on window focus
 * - 30-second throttled manual refresh
 * - Independent query slices (Promise.allSettled)
 */

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState, useCallback } from "react";
import { Firm } from "@/types/firestore";
import {
  fetchHeadlineKpis,
  fetchSeatUsage,
  fetchOnboardingFunnel,
  fetchDepartmentBreakdown,
  fetchRoleDistribution,
  fetchJoinsOverTime,
  fetchGroupsOverview,
  fetchNeedsAttention,
  fetchNoticesOversight,
  fetchPresenceEngagement,
  fetchRecentActivity,
} from "./repository";
import { DashboardBundle, NeedsAttentionItem } from "@/types/metrics";

const FIVE_MINUTES_MS = 5 * 60 * 1000;
const THIRTY_SECONDS_MS = 30 * 1000;

export function useDashboardMetrics(firm: Firm | null, weeks: number = 8) {
  const queryClient = useQueryClient();
  const [lastManualRefresh, setLastManualRefresh] = useState<number>(0);
  const [isThrottled, setIsThrottled] = useState<boolean>(false);

  const queryKey = ["dashboardMetrics", firm?.firmId, weeks];

  const queryResult = useQuery<DashboardBundle>({
    queryKey,
    enabled: !!firm && !!firm.firmId,
    staleTime: FIVE_MINUTES_MS,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
    queryFn: async () => {
      if (!firm || !firm.firmId) {
        throw new Error("No firm selected");
      }

      const firmId = firm.firmId;
      const fetchTime = new Date();

      // 1. Fetch headline KPIs first to provide active/invited counts for reuse
      const headlineKpis = await fetchHeadlineKpis(firmId);

      // 2. Fetch all remaining metric slices in parallel with Promise.allSettled
      const [
        seatUsageRes,
        funnelRes,
        deptBreakdownRes,
        roleDistRes,
        joinsRes,
        groupsRes,
        noticesRes,
        presenceRes,
        activityRes,
      ] = await Promise.allSettled([
        fetchSeatUsage(firm, headlineKpis.activeStaff, headlineKpis.pendingStaff),
        fetchOnboardingFunnel(firmId),
        fetchDepartmentBreakdown(firmId, headlineKpis.activeStaff),
        fetchRoleDistribution(firmId),
        fetchJoinsOverTime(firmId, weeks),
        fetchGroupsOverview(firmId),
        fetchNoticesOversight(firmId, headlineKpis.activeStaff),
        fetchPresenceEngagement(firmId, firm.showLastSeen),
        fetchRecentActivity(firmId, 10),
      ]);

      const seatUsage =
        seatUsageRes.status === "fulfilled"
          ? seatUsageRes.value
          : {
              storedSeatCount: firm.seatCount,
              seatLimit: firm.seatLimit,
              trueSeatCount: firm.seatCount,
              isOutOfSync: false,
              ratio: Math.min(1.0, firm.seatCount / (firm.seatLimit || 1)),
              remainingSeats: Math.max(0, firm.seatLimit - firm.seatCount),
            };

      const funnel =
        funnelRes.status === "fulfilled"
          ? funnelRes.value
          : { totalInvited: 0, codePending: 0, joined: 0, expired: 0, conversionRate: 0 };

      const departmentBreakdown =
        deptBreakdownRes.status === "fulfilled"
          ? deptBreakdownRes.value
          : { departments: [], unassignedCount: 0 };

      const roleDistribution =
        roleDistRes.status === "fulfilled"
          ? roleDistRes.value
          : { adminCount: 0, leadCount: 0, employeeCount: 0, total: 0 };

      const joinsOverTime =
        joinsRes.status === "fulfilled"
          ? joinsRes.value
          : { requestedWeeks: weeks, weeklyBuckets: [], excludedNoJoinDateCount: 0 };

      const groupsOverview =
        groupsRes.status === "fulfilled"
          ? groupsRes.value
          : { activeDepartments: 0, archivedDepartments: 0, activeProjects: 0, archivedProjects: 0 };

      const noticesOversight =
        noticesRes.status === "fulfilled"
          ? noticesRes.value
          : {
              publishedCount: 0,
              urgentCount: 0,
              policyCount: 0,
              latestPolicyAckCount: 0,
              activeMembersCount: 0,
            };

      const presenceEngagement =
        presenceRes.status === "fulfilled"
          ? presenceRes.value
          : { activeInLast7Days: null, isPrivacyDisabled: !firm.showLastSeen };

      const recentActivity =
        activityRes.status === "fulfilled" ? activityRes.value : [];

      // 3. Needs Attention uses departments from breakdown
      let attentionItems: NeedsAttentionItem[] = [];
      try {
        attentionItems = await fetchNeedsAttention(
          firmId,
          departmentBreakdown.departments
        );
      } catch (e) {
        console.error("Error fetching needs attention:", e);
      }

      return {
        headlineKpis,
        seatUsage,
        funnel,
        departmentBreakdown,
        roleDistribution,
        joinsOverTime,
        groupsOverview,
        needsAttention: attentionItems,
        noticesOversight,
        presenceEngagement,
        recentActivity,
        lastFetched: fetchTime,
      };
    },
  });

  // Throttled manual refresh callable by user (at most once every 30 seconds)
  const refresh = useCallback(async () => {
    const now = Date.now();
    if (now - lastManualRefresh < THIRTY_SECONDS_MS) {
      setIsThrottled(true);
      setTimeout(() => setIsThrottled(false), 3000);
      return false;
    }

    setLastManualRefresh(now);
    setIsThrottled(false);
    await queryClient.invalidateQueries({ queryKey });
    return true;
  }, [lastManualRefresh, queryClient, queryKey]);

  return {
    ...queryResult,
    refresh,
    isThrottled,
  };
}
