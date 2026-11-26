"use client";

import React from "react";
import { Activity, EyeOff, ShieldCheck, HelpCircle } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { PresenceEngagement } from "@/types/metrics";

interface PresenceCardProps {
  data: PresenceEngagement;
  isLoading?: boolean;
}

export function PresenceCard({ data, isLoading = false }: PresenceCardProps) {
  const { activeInLast7Days, isPrivacyDisabled } = data;

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-emerald-500/10 p-1.5 text-emerald-400">
            <Activity className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Weekly Engagement</CardTitle>
            <p className="text-xs text-muted-foreground">Firm-level active engagement aggregate</p>
          </div>
        </div>

        <div className="flex items-center space-x-1 text-xs text-muted-foreground">
          <ShieldCheck className="h-3.5 w-3.5 text-primary" />
          <span className="text-[11px]">Privacy by Design</span>
        </div>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="space-y-2">
            <div className="h-8 w-24 animate-pulse rounded bg-muted/60" />
            <div className="h-4 w-48 animate-pulse rounded bg-muted/30" />
          </div>
        ) : isPrivacyDisabled ? (
          <div className="flex items-center space-x-3 rounded-lg border border-border/80 bg-muted/20 p-3 text-xs">
            <EyeOff className="h-5 w-5 text-muted-foreground shrink-0" />
            <div>
              <div className="flex items-center space-x-1 font-semibold text-foreground">
                <span>Active last 7 days:</span>
                <span className="font-mono text-muted-foreground">—</span>
              </div>
              <p className="text-[11px] text-muted-foreground mt-0.5">
                Privacy setting is disabled by firm policy (`showLastSeen: false`).
              </p>
            </div>
          </div>
        ) : (
          <div>
            <div className="flex items-baseline space-x-2">
              <span className="text-3xl font-extrabold text-foreground">
                {activeInLast7Days !== null ? activeInLast7Days : "—"}
              </span>
              <span className="text-xs text-muted-foreground">active staff in past 7 days</span>
            </div>

            <div className="mt-2 flex items-center space-x-1.5 text-[11px] text-muted-foreground border-t border-border/40 pt-2">
              <Tooltip>
                <TooltipTrigger asChild>
                  <span className="flex items-center space-x-1 cursor-help hover:text-foreground">
                    <HelpCircle className="h-3.5 w-3.5" />
                    <span>Calculated strictly from firm-level presence heartbeats. Individual member activity is never tracked.</span>
                  </span>
                </TooltipTrigger>
                <TooltipContent side="top" className="max-w-xs text-xs">
                  ProntoChat never tracks employee messages, read times, or individual last seen records. Only aggregate counts are surfaced.
                </TooltipContent>
              </Tooltip>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

