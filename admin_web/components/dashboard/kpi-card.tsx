"use client";

import React from "react";
import { ArrowUpRight, ArrowDownRight, ExternalLink } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

interface KpiCardProps {
  title: string;
  count: number;
  delta: number;
  icon: React.ElementType;
  colorClass?: string;
  deltaLabel?: string;
  legacyLink?: string;
  isLoading?: boolean;
}

export function KpiCard({
  title,
  count,
  delta,
  icon: Icon,
  colorClass = "text-primary",
  deltaLabel = "this week",
  legacyLink,
  isLoading = false,
}: KpiCardProps) {
  const isPositiveDelta = delta > 0;
  const isZeroDelta = delta === 0;

  const content = (
    <Card className="relative overflow-hidden transition-all duration-200 hover:shadow-lg group">
      <CardContent className="p-5">
        <div className="flex items-center justify-between">
          <span className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
            {title}
          </span>
          <div className={cn("rounded-lg p-2 bg-muted/40", colorClass)}>
            <Icon className="h-4 w-4" />
          </div>
        </div>

        <div className="mt-3 flex items-baseline justify-between">
          <div className="text-3xl font-extrabold tracking-tight text-foreground">
            {isLoading ? (
              <span className="inline-block h-8 w-16 animate-pulse rounded bg-muted/60" />
            ) : (
              count.toLocaleString()
            )}
          </div>

          {!isLoading && (
            <div className="flex items-center text-xs">
              <span
                className={cn(
                  "flex items-center font-semibold",
                  isZeroDelta
                    ? "text-muted-foreground"
                    : isPositiveDelta
                    ? "text-emerald-400"
                    : "text-rose-400"
                )}
              >
                {!isZeroDelta && (
                  isPositiveDelta ? (
                    <ArrowUpRight className="mr-0.5 h-3.5 w-3.5" />
                  ) : (
                    <ArrowDownRight className="mr-0.5 h-3.5 w-3.5" />
                  )
                )}
                {isPositiveDelta ? `+${delta}` : delta}
              </span>
              <span className="ml-1 text-[11px] text-muted-foreground">{deltaLabel}</span>
            </div>
          )}
        </div>

        {legacyLink && (
          <div className="mt-3 flex items-center justify-between border-t border-border/50 pt-2 text-[11px] text-muted-foreground group-hover:text-primary transition-colors">
            <span>View directory breakdown</span>
            <div className="flex items-center space-x-1">
              <Badge variant="outline" className="text-[9px] py-0 px-1 border-border/60">Legacy</Badge>
              <ExternalLink className="h-3 w-3" />
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );

  if (legacyLink) {
    return (
      <a href={legacyLink} className="block transition-transform hover:-translate-y-0.5">
        {content}
      </a>
    );
  }

  return content;
}

