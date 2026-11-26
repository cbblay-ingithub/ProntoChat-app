"use client";

import React from "react";
import { Bell, AlertCircle, FileText, CheckCheck, ExternalLink } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { NoticesOversight } from "@/types/metrics";

interface NoticesCardProps {
  data: NoticesOversight;
  isLoading?: boolean;
}

export function NoticesCard({ data, isLoading = false }: NoticesCardProps) {
  const {
    publishedCount,
    urgentCount,
    policyCount,
    latestPolicyAuthor,
    latestPolicyVersion,
    latestPolicyAckRate,
    latestPolicyAckCount,
    activeMembersCount,
  } = data;

  const hasNotices = publishedCount > 0;

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-emerald-500/10 p-1.5 text-emerald-400">
            <Bell className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Notices Oversight</CardTitle>
            <p className="text-xs text-muted-foreground">Firm broadcasts and policy compliance</p>
          </div>
        </div>

        <a
          href="/#/admin/notices"
          className="flex items-center space-x-1 text-xs text-muted-foreground hover:text-primary transition-colors"
        >
          <span>Manage</span>
          <ExternalLink className="h-3 w-3" />
        </a>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="space-y-3">
            <div className="grid grid-cols-3 gap-2">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-14 animate-pulse rounded-lg bg-muted/40" />
              ))}
            </div>
            <div className="h-16 animate-pulse rounded-lg bg-muted/20" />
          </div>
        ) : !hasNotices ? (
          <div className="flex h-36 flex-col items-center justify-center text-center p-4 text-muted-foreground">
            <Bell className="h-8 w-8 stroke-1 text-muted-foreground/40 mb-2" />
            <p className="text-sm font-medium">No published notices</p>
            <p className="text-xs text-muted-foreground/70 max-w-xs mt-1">
              Company-wide announcements and mandatory policies will appear here.
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Quick Metadata Stats */}
            <div className="grid grid-cols-3 gap-2">
              <div className="rounded-lg border border-border/80 bg-muted/20 p-2.5 text-center">
                <span className="text-[10px] font-medium text-muted-foreground uppercase">Published</span>
                <p className="text-lg font-bold text-foreground">{publishedCount}</p>
              </div>

              <div className="rounded-lg border border-border/80 bg-rose-500/10 p-2.5 text-center">
                <div className="flex items-center justify-center space-x-1 text-rose-400 text-[10px] font-medium uppercase">
                  <AlertCircle className="h-3 w-3" />
                  <span>Urgent</span>
                </div>
                <p className="text-lg font-bold text-rose-400">{urgentCount}</p>
              </div>

              <div className="rounded-lg border border-border/80 bg-purple-500/10 p-2.5 text-center">
                <div className="flex items-center justify-center space-x-1 text-purple-400 text-[10px] font-medium uppercase">
                  <FileText className="h-3 w-3" />
                  <span>Policies</span>
                </div>
                <p className="text-lg font-bold text-purple-400">{policyCount}</p>
              </div>
            </div>

            {/* Latest Policy Acknowledgement Tracker */}
            {policyCount > 0 && latestPolicyAckRate !== undefined ? (
              <div className="rounded-lg border border-border/80 bg-muted/30 p-3">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-semibold text-foreground flex items-center space-x-1.5">
                    <CheckCheck className="h-4 w-4 text-emerald-400" />
                    <span>Latest Policy Compliance</span>
                  </span>
                  <Badge variant="outline" className="text-[10px] py-0 px-1.5">
                    v{latestPolicyVersion || 1}
                  </Badge>
                </div>

                <div className="mt-2 flex items-baseline justify-between text-xs">
                  <span className="text-muted-foreground">
                    Acknowledged by <strong className="text-foreground">{latestPolicyAckCount}</strong> of{" "}
                    <strong className="text-foreground">{activeMembersCount}</strong> active staff
                  </span>
                  <span className="font-bold text-emerald-400">
                    {latestPolicyAckRate.toFixed(1)}%
                  </span>
                </div>

                <div className="mt-1.5 h-2 w-full overflow-hidden rounded-full bg-muted">
                  <div
                    className="h-full rounded-full bg-emerald-500 transition-all duration-500"
                    style={{ width: `${Math.min(100, latestPolicyAckRate)}%` }}
                  />
                </div>
                {latestPolicyAuthor && (
                  <p className="mt-2 text-[10px] text-muted-foreground">
                    Author: {latestPolicyAuthor}
                  </p>
                )}
              </div>
            ) : null}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

