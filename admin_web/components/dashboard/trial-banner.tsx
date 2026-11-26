"use client";

import React from "react";
import { AlertCircle, HelpCircle } from "lucide-react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { Firm } from "@/types/firestore";

interface TrialBannerProps {
  firm: Firm | null;
}

export function TrialBanner({ firm }: TrialBannerProps) {
  // If firm has no trialEndDate stored, raise an alert per Decision 7 instead of inventing numbers.
  const hasTrialEndDate = false; // Firm data model only contains plan: 'trial' with fixed 5 seats

  return (
    <div className="flex items-center justify-between rounded-xl border border-border/80 bg-card/60 p-4 shadow-sm">
      <div className="flex items-center space-x-3">
        <div className="rounded-lg bg-amber-500/10 p-2 text-amber-400">
          <AlertCircle className="h-5 w-5" />
        </div>
        <div>
          <div className="flex items-center space-x-2">
            <span className="text-sm font-semibold text-foreground">Trial Tier Plan Status</span>
            <span className="rounded bg-primary/15 px-2 py-0.5 text-[10px] font-bold tracking-wider text-primary uppercase">
              {firm?.plan || "Trial"}
            </span>
          </div>
          <p className="text-xs text-muted-foreground mt-0.5">
            Workspace is running under Spark Free Plan limits with 5 capped team seats.
          </p>
        </div>
      </div>

      <div className="flex items-center space-x-2">
        <div className="text-right">
          <div className="flex items-center space-x-1 justify-end">
            <span className="text-sm font-bold text-foreground">Trial Days Remaining:</span>
            <span className="font-mono text-sm font-semibold text-muted-foreground">—</span>
            <Tooltip>
              <TooltipTrigger asChild>
                <button className="text-muted-foreground hover:text-foreground">
                  <HelpCircle className="h-3.5 w-3.5" />
                </button>
              </TooltipTrigger>
              <TooltipContent side="top" className="max-w-xs text-xs">
                Trial expiration is not tracked in the firm record. The trial plan remains active under the 5-seat quota until upgraded or altered.
              </TooltipContent>
            </Tooltip>
          </div>
          <span className="text-[11px] text-muted-foreground">No expiration date configured in firm schema</span>
        </div>
      </div>
    </div>
  );
}

