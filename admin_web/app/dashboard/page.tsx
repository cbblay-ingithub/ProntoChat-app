"use client";

import React, { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Users,
  UserCheck,
  UserPlus,
  UserMinus,
  AlertOctagon,
  WifiOff,
  ShieldAlert,
} from "lucide-react";
import { Sidebar } from "@/components/layout/sidebar";
import { TopBar } from "@/components/layout/top-bar";
import { KpiCard } from "@/components/dashboard/kpi-card";
import { SeatMeter } from "@/components/dashboard/seat-meter";
import { TrialBanner } from "@/components/dashboard/trial-banner";
import { OnboardingFunnelCard } from "@/components/dashboard/charts/onboarding-funnel-card";
import { DepartmentHeadcountCard } from "@/components/dashboard/charts/department-headcount-card";
import { RoleDistributionCard } from "@/components/dashboard/charts/role-distribution-card";
import { JoinsOverTimeCard } from "@/components/dashboard/charts/joins-over-time-card";
import { NeedsAttentionCard } from "@/components/dashboard/needs-attention-card";
import { NoticesCard } from "@/components/dashboard/notices-card";
import { RecentActivityCard } from "@/components/dashboard/recent-activity-card";
import { PresenceCard } from "@/components/dashboard/presence-card";
import { GroupsSummaryCard } from "@/components/dashboard/groups-summary-card";
import { QuickActions } from "@/components/dashboard/quick-actions";
import { subscribeToAuthState, resolveAdminSession, ResolvedAdminSession } from "@/lib/firebase/auth";
import { useDashboardMetrics } from "@/lib/metrics/use-dashboard";

export default function DashboardPage() {
  const router = useRouter();
  const [session, setSession] = useState<ResolvedAdminSession | null>(null);
  const [isAuthLoading, setIsAuthLoading] = useState(true);
  const [selectedWeeks, setSelectedWeeks] = useState(8);

  // Auth & Session listener
  useEffect(() => {
    const unsubscribe = subscribeToAuthState(async (user) => {
      if (!user) {
        router.replace("/sign-in/");
        return;
      }

      const res = await resolveAdminSession(user);
      setSession(res);
      setIsAuthLoading(false);

      if (!res.isAdmin) {
        // Redirect non-admins to employee messaging per spec
        window.location.href = "/#/home";
      }
    });

    return () => unsubscribe();
  }, [router]);

  // Metric bundle loaded via TanStack Query (5-minute TTL, throttled refresh)
  const {
    data: bundle,
    isLoading: isMetricsLoading,
    isError,
    error,
    refetch,
    refresh,
    isThrottled,
    isFetching,
  } = useDashboardMetrics(session?.firm || null, selectedWeeks);

  if (isAuthLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center space-y-3">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          <p className="text-xs text-muted-foreground animate-pulse">Initializing Admin Session...</p>
        </div>
      </div>
    );
  }

  // Handle Suspended Firm State
  if (session?.isFirmSuspended) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background p-4">
        <div className="max-w-md text-center p-6 rounded-xl border border-destructive/40 bg-card shadow-2xl">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-destructive/15 text-destructive mb-3">
            <AlertOctagon className="h-6 w-6" />
          </div>
          <h2 className="text-lg font-bold text-foreground">Workspace Suspended</h2>
          <p className="text-xs text-muted-foreground mt-2">
            This organization has been temporarily suspended by system administrators. You cannot inspect metrics while the workspace is suspended.
          </p>
          <div className="mt-5">
            <a
              href="/#/home"
              className="inline-flex items-center justify-center rounded-lg bg-primary px-4 py-2 text-xs font-semibold text-primary-foreground hover:bg-primary/90"
            >
              Return to Messaging
            </a>
          </div>
        </div>
      </div>
    );
  }

  // Handle Access Revoked State
  if (session?.isRevoked) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background p-4">
        <div className="max-w-md text-center p-6 rounded-xl border border-destructive/40 bg-card shadow-2xl">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-destructive/15 text-destructive mb-3">
            <ShieldAlert className="h-6 w-6" />
          </div>
          <h2 className="text-lg font-bold text-foreground">Access Revoked</h2>
          <p className="text-xs text-muted-foreground mt-2">
            Your membership in this firm has been revoked. Please contact your organization owner.
          </p>
        </div>
      </div>
    );
  }

  // Handle Offline / Permission Denied Error
  if (isError) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background p-4">
        <div className="max-w-md text-center p-6 rounded-xl border border-destructive/30 bg-card">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-destructive/10 text-destructive mb-3">
            <WifiOff className="h-6 w-6" />
          </div>
          <h2 className="text-lg font-bold text-foreground">Failed to Load Dashboard</h2>
          <p className="text-xs text-muted-foreground mt-2">
            {(error as Error)?.message || "A network or permission error occurred while reading Firestore."}
          </p>
          <button
            onClick={() => refetch()}
            className="mt-4 rounded-lg bg-primary px-4 py-2 text-xs font-semibold text-primary-foreground hover:bg-primary/90"
          >
            Retry Query
          </button>
        </div>
      </div>
    );
  }

  const kpis = bundle?.headlineKpis || {
    totalStaff: 0,
    activeStaff: 0,
    pendingStaff: 0,
    revokedStaff: 0,
    activeDelta: 0,
    pendingDelta: 0,
    revokedDelta: 0,
    totalDelta: 0,
  };

  const adminDisplayName =
    session?.user.displayName ||
    session?.membership?.name ||
    session?.user.email?.split("@")[0] ||
    "Administrator";

  return (
    <div className="flex min-h-screen bg-background">
      {/* Collapsible Sidebar */}
      <Sidebar firm={session?.firm || null} />

      {/* Main Content Area */}
      <div className="flex flex-1 flex-col overflow-y-auto">
        <TopBar
          firm={session?.firm || null}
          membership={session?.membership || null}
          adminName={adminDisplayName}
          lastUpdated={bundle?.lastFetched}
          onRefresh={refresh}
          isFetching={isFetching}
          isThrottled={isThrottled}
        />

        <main className="flex-1 p-4 sm:p-6 lg:p-8">
          <div className="mx-auto max-w-[1440px] space-y-6">
            {/* Row 0: Trial Plan Banner & Alert */}
            <TrialBanner firm={session?.firm || null} />

            {/* Row 1: Headline KPIs (Total, Active, Pending, Revoked) */}
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <KpiCard
                title="Total Staff"
                count={kpis.totalStaff}
                delta={kpis.totalDelta}
                icon={Users}
                colorClass="text-primary"
                legacyLink="/#/admin/onboarding?filter=all"
                isLoading={isMetricsLoading}
              />
              <KpiCard
                title="Active Staff"
                count={kpis.activeStaff}
                delta={kpis.activeDelta}
                icon={UserCheck}
                colorClass="text-emerald-400"
                legacyLink="/#/admin/onboarding?filter=active"
                isLoading={isMetricsLoading}
              />
              <KpiCard
                title="Pending Staff"
                count={kpis.pendingStaff}
                delta={kpis.pendingDelta}
                icon={UserPlus}
                colorClass="text-amber-400"
                legacyLink="/#/admin/onboarding?filter=pending"
                isLoading={isMetricsLoading}
              />
              <KpiCard
                title="Revoked Staff"
                count={kpis.revokedStaff}
                delta={kpis.revokedDelta}
                icon={UserMinus}
                colorClass="text-rose-400"
                legacyLink="/#/admin/onboarding?filter=revoked"
                isLoading={isMetricsLoading}
              />
            </div>

            {/* Row 2: Funnel & Joins Over Time beside Seat Meter & Quick Actions */}
            <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
              <div className="lg:col-span-7 space-y-6">
                {/* Onboarding Funnel */}
                <OnboardingFunnelCard
                  data={bundle?.funnel || { totalInvited: 0, codePending: 0, joined: 0, expired: 0, conversionRate: 0 }}
                  isLoading={isMetricsLoading}
                />
                {/* Joins Over Time */}
                <JoinsOverTimeCard
                  data={bundle?.joinsOverTime || { requestedWeeks: selectedWeeks, weeklyBuckets: [], excludedNoJoinDateCount: 0 }}
                  selectedWeeks={selectedWeeks}
                  onSelectWeeks={setSelectedWeeks}
                  isLoading={isMetricsLoading}
                />
              </div>

              <div className="lg:col-span-5 space-y-6">
                {/* Seat Meter */}
                <SeatMeter
                  data={
                    bundle?.seatUsage || {
                      storedSeatCount: session?.firm?.seatCount || 1,
                      seatLimit: session?.firm?.seatLimit || 5,
                      trueSeatCount: 1,
                      isOutOfSync: false,
                      ratio: 0.2,
                      remainingSeats: 4,
                    }
                  }
                  isLoading={isMetricsLoading}
                />
                {/* Quick Actions */}
                <QuickActions firmId={session?.firm?.firmId} />
                {/* Groups Overview */}
                <GroupsSummaryCard
                  data={bundle?.groupsOverview || { activeDepartments: 0, archivedDepartments: 0, activeProjects: 0, archivedProjects: 0 }}
                  isLoading={isMetricsLoading}
                />
              </div>
            </div>

            {/* Row 3: Department Headcount beside Role Distribution */}
            <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
              <div className="lg:col-span-7">
                <DepartmentHeadcountCard
                  data={bundle?.departmentBreakdown || { departments: [], unassignedCount: 0 }}
                  isLoading={isMetricsLoading}
                />
              </div>

              <div className="lg:col-span-5">
                <RoleDistributionCard
                  data={bundle?.roleDistribution || { adminCount: 0, leadCount: 0, employeeCount: 0, total: 0 }}
                  isLoading={isMetricsLoading}
                />
              </div>
            </div>

            {/* Row 4: Needs Attention beside Recent Audit Activity & Presence */}
            <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
              <div className="lg:col-span-7 space-y-6">
                <NeedsAttentionCard
                  items={bundle?.needsAttention || []}
                  isLoading={isMetricsLoading}
                />
                <NoticesCard
                  data={bundle?.noticesOversight || { publishedCount: 0, urgentCount: 0, policyCount: 0, latestPolicyAckCount: 0, activeMembersCount: 0 }}
                  isLoading={isMetricsLoading}
                />
              </div>

              <div className="lg:col-span-5 space-y-6">
                <PresenceCard
                  data={bundle?.presenceEngagement || { activeInLast7Days: null, isPrivacyDisabled: false }}
                  isLoading={isMetricsLoading}
                />
                <RecentActivityCard
                  activity={bundle?.recentActivity || []}
                  isLoading={isMetricsLoading}
                />
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}

