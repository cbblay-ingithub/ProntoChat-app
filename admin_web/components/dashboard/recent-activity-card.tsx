"use client";

import React from "react";
import { History, Shield, User, Building, FileText, CheckCircle2 } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { formatTimeLocal, formatUnambiguousDate } from "@/lib/format/date";
import { AuditEntry } from "@/types/firestore";

interface RecentActivityCardProps {
  activity: AuditEntry[];
  isLoading?: boolean;
}

export function RecentActivityCard({ activity, isLoading = false }: RecentActivityCardProps) {
  const getActionIcon = (action: string) => {
    if (action.includes("staff")) return <User className="h-3.5 w-3.5 text-primary" />;
    if (action.includes("dept")) return <Building className="h-3.5 w-3.5 text-blue-400" />;
    if (action.includes("notice")) return <FileText className="h-3.5 w-3.5 text-purple-400" />;
    return <Shield className="h-3.5 w-3.5 text-amber-400" />;
  };

  const formatActionDescription = (entry: AuditEntry) => {
    switch (entry.action) {
      case "staff_added":
        return `Added staff code for ${entry.targetLabel || "employee"}`;
      case "staff_revoked":
        return `Revoked access for ${entry.targetLabel || "member"}`;
      case "staff_reinstated":
        return `Reinstated access for ${entry.targetLabel || "member"}`;
      case "code_reset":
        return `Regenerated one-time code for ${entry.targetLabel || "staff"}`;
      case "dept_created":
        return `Created department "${entry.targetLabel}"`;
      case "dept_head_assigned":
        return `Assigned head of department for "${entry.targetLabel}"`;
      case "notice_published":
        return `Published broadcast notice: "${entry.targetLabel}"`;
      case "notice_retracted":
        return `Retracted notice: "${entry.targetLabel}"`;
      default:
        return entry.action.replace(/_/g, " ") + (entry.targetLabel ? ` (${entry.targetLabel})` : "");
    }
  };

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-primary/10 p-1.5 text-primary">
            <History className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Audit Activity Log</CardTitle>
            <p className="text-xs text-muted-foreground">Recent administrative events</p>
          </div>
        </div>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-10 w-full animate-pulse rounded-lg bg-muted/40" />
            ))}
          </div>
        ) : activity.length === 0 ? (
          <div className="flex h-44 flex-col items-center justify-center text-center p-4 text-muted-foreground">
            <CheckCircle2 className="h-8 w-8 stroke-1 text-muted-foreground/40 mb-2" />
            <p className="text-sm font-medium text-foreground">No recent administrative events</p>
            <p className="text-xs text-muted-foreground/70 max-w-xs mt-1">
              Events such as adding staff, resetting codes, or assigning leads will be logged here.
            </p>
          </div>
        ) : (
          <div className="divide-y divide-border/60">
            {activity.slice(0, 10).map((entry) => (
              <div key={entry.id} className="flex items-start justify-between py-2.5 text-xs">
                <div className="flex items-start space-x-2.5">
                  <div className="mt-0.5 rounded-full bg-muted/80 p-1 shrink-0">
                    {getActionIcon(entry.action)}
                  </div>
                  <div>
                    <span className="font-medium text-foreground">{formatActionDescription(entry)}</span>
                    <p className="text-[11px] text-muted-foreground mt-0.5">
                      by <strong className="text-foreground/80">{entry.actorName || "Admin"}</strong>
                    </p>
                  </div>
                </div>

                <span className="text-[10px] text-muted-foreground shrink-0 pl-2">
                  {formatTimeLocal(entry.createdAt)}
                </span>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

