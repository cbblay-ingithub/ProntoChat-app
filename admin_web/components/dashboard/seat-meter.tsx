"use client";

import React from "react";
import { Users, AlertTriangle, Info } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { SeatUsage } from "@/types/metrics";
import { cn } from "@/lib/utils";

interface SeatMeterProps {
  data: SeatUsage;
  isLoading?: boolean;
}

export function SeatMeter({ data, isLoading = false }: SeatMeterProps) {
  const { storedSeatCount, seatLimit, trueSeatCount, isOutOfSync, ratio, remainingSeats } = data;
  const percentage = Math.round(ratio * 100);

  // Proposed Color Thresholds:
  // < 70%: Healthy (Green)
  // 70% - 90%: Near Capacity (Amber)
  // >= 90%: Critical / Full (Rose/Red)
  let barColorClass = "bg-primary";
  let statusText = "Available";
  let badgeVariant: "default" | "warning" | "destructive" = "default";

  if (percentage >= 90) {
    barColorClass = "bg-rose-500";
    statusText = percentage >= 100 ? "Cap Reached" : "Near Capacity";
    badgeVariant = "destructive";
  } else if (percentage >= 70) {
    barColorClass = "bg-amber-500";
    statusText = "Approaching Limit";
    badgeVariant = "warning";
  }

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-primary/10 p-1.5 text-primary">
            <Users className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Seat Allocation</CardTitle>
            <p className="text-xs text-muted-foreground">Active staff + pending invitees</p>
          </div>
        </div>

        <Badge variant={badgeVariant} className="text-xs font-semibold">
          {statusText}
        </Badge>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="space-y-3">
            <div className="h-5 w-24 animate-pulse rounded bg-muted/60" />
            <div className="h-3 w-full animate-pulse rounded-full bg-muted/40" />
          </div>
        ) : (
          <>
            <div className="flex items-baseline justify-between mb-2">
              <div className="flex items-baseline space-x-1">
                <span className="text-2xl font-bold text-foreground">{trueSeatCount}</span>
                <span className="text-sm text-muted-foreground">/ {seatLimit} seats used</span>
              </div>
              <span className="text-xs font-semibold text-muted-foreground">
                {percentage}%
              </span>
            </div>

            {/* Progress Bar */}
            <div className="relative h-2.5 w-full overflow-hidden rounded-full bg-muted">
              <div
                className={cn("h-full rounded-full transition-all duration-500 ease-out", barColorClass)}
                style={{ width: `${Math.min(100, percentage)}%` }}
              />
            </div>

            <div className="mt-3 flex items-center justify-between text-xs text-muted-foreground">
              <span>{remainingSeats} seat{remainingSeats === 1 ? "" : "s"} remaining</span>
              <Tooltip>
                <TooltipTrigger asChild>
                  <span className="inline-flex items-center cursor-help space-x-1 text-[11px] text-muted-foreground/80 hover:text-foreground">
                    <Info className="h-3.5 w-3.5" />
                    <span>How seats are calculated</span>
                  </span>
                </TooltipTrigger>
                <TooltipContent side="top" className="max-w-xs text-xs">
                  Seats reflect the true sum of active staff members plus pre-approved invitation codes that have not yet expired or joined.
                </TooltipContent>
              </Tooltip>
            </div>

            {/* Seat Counter Out of Sync Notice (Admin Only) */}
            {isOutOfSync && (
              <div className="mt-3 flex items-start space-x-2 rounded-lg border border-amber-500/30 bg-amber-500/10 p-2.5 text-xs text-amber-300">
                <AlertTriangle className="h-4 w-4 shrink-0 mt-0.5 text-amber-400" />
                <div className="flex-1">
                  <span className="font-semibold">Seat counter out of sync:</span>{" "}
                  True allocation is <strong className="text-amber-200">{trueSeatCount}</strong>, but firm stored count is{" "}
                  <strong className="text-amber-200">{storedSeatCount}</strong>.
                </div>
              </div>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}

