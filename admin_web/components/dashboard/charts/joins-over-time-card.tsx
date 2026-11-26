"use client";

import React, { useState } from "react";
import { TrendingUp, Table as TableIcon, LineChart as LineChartIcon, Info } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { JoinsOverTime } from "@/types/metrics";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
} from "recharts";

interface JoinsOverTimeCardProps {
  data: JoinsOverTime;
  selectedWeeks: number;
  onSelectWeeks: (weeks: number) => void;
  isLoading?: boolean;
}

export function JoinsOverTimeCard({
  data,
  selectedWeeks,
  onSelectWeeks,
  isLoading = false,
}: JoinsOverTimeCardProps) {
  const [showTable, setShowTable] = useState(false);
  const { weeklyBuckets, excludedNoJoinDateCount } = data;

  const totalInWindow = weeklyBuckets.reduce((sum, b) => sum + b.count, 0);
  const isEmpty = weeklyBuckets.length === 0 || totalInWindow === 0;

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-emerald-500/10 p-1.5 text-emerald-400">
            <TrendingUp className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Joins Over Time</CardTitle>
            <p className="text-xs text-muted-foreground">
              {totalInWindow} new staff in past {selectedWeeks} weeks (weeks start Mon)
            </p>
          </div>
        </div>

        <div className="flex items-center space-x-2">
          {/* Horizon Selector (4, 8, 12 weeks) */}
          <div className="flex rounded-lg border border-border p-0.5 bg-muted/40">
            {[4, 8, 12].map((w) => (
              <button
                key={w}
                onClick={() => onSelectWeeks(w)}
                className={`rounded-md px-2 py-0.5 text-xs font-medium transition-colors ${
                  selectedWeeks === w
                    ? "bg-card text-foreground font-semibold shadow-sm"
                    : "text-muted-foreground hover:text-foreground"
                }`}
              >
                {w}w
              </button>
            ))}
          </div>

          <Button
            variant="ghost"
            size="sm"
            onClick={() => setShowTable(!showTable)}
            className="h-8 gap-1 text-xs text-muted-foreground"
            aria-label="Toggle view data as table"
          >
            {showTable ? <LineChartIcon className="h-3.5 w-3.5" /> : <TableIcon className="h-3.5 w-3.5" />}
            <span>{showTable ? "Chart" : "Table"}</span>
          </Button>
        </div>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="flex h-52 items-center justify-center">
            <div className="h-40 w-full animate-pulse rounded-lg bg-muted/30" />
          </div>
        ) : isEmpty ? (
          <div className="flex h-52 flex-col items-center justify-center text-center p-4 text-muted-foreground">
            <TrendingUp className="h-8 w-8 stroke-1 text-muted-foreground/40 mb-2" />
            <p className="text-sm font-medium">No recent joins recorded</p>
            <p className="text-xs text-muted-foreground/70 max-w-xs mt-1">
              New team members joining within the selected {selectedWeeks}-week window will generate trendlines.
            </p>
          </div>
        ) : showTable ? (
          <div className="h-52 overflow-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Week Commencing</TableHead>
                  <TableHead className="text-right">New Members</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {weeklyBuckets.map((row) => (
                  <TableRow key={row.weekStart}>
                    <TableCell className="font-medium">{row.label}</TableCell>
                    <TableCell className="text-right font-mono">{row.count}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        ) : (
          <div className="h-52 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={weeklyBuckets} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="joinsGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10B981" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="#10B981" stopOpacity={0.0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="label" tick={{ fill: "#A3A3A3", fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: "#A3A3A3", fontSize: 11 }} axisLine={false} tickLine={false} allowDecimals={false} />
                <RechartsTooltip
                  content={({ active, payload }) => {
                    if (active && payload && payload.length) {
                      const item = payload[0].payload;
                      return (
                        <div className="rounded-lg border border-border bg-card p-2 shadow-lg text-xs">
                          <p className="font-semibold text-foreground">Week of {item.label}</p>
                          <p className="text-muted-foreground">
                            New joins: <strong className="text-emerald-400">{item.count}</strong>
                          </p>
                        </div>
                      );
                    }
                    return null;
                  }}
                />
                <Area
                  type="monotone"
                  dataKey="count"
                  stroke="#10B981"
                  strokeWidth={2}
                  fillOpacity={1}
                  fill="url(#joinsGradient)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}

        {/* Missing field boundary indicator per prompt specification */}
        {excludedNoJoinDateCount > 0 && (
          <div className="mt-2 flex items-center justify-between border-t border-border/50 pt-2 text-[11px] text-muted-foreground">
            <div className="flex items-center space-x-1 text-amber-400">
              <Info className="h-3.5 w-3.5" />
              <span>{excludedNoJoinDateCount} member record{excludedNoJoinDateCount === 1 ? "" : "s"} lack joinedAt timestamp</span>
            </div>
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="cursor-help underline underline-offset-2">Why are these excluded?</span>
              </TooltipTrigger>
              <TooltipContent side="top" className="max-w-xs text-xs">
                To prevent timeline distortion, records created before join timestamps were recorded or missing the joinedAt field are excluded from the weekly buckets.
              </TooltipContent>
            </Tooltip>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

