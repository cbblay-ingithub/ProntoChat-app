"use client";

import React, { useState } from "react";
import { UserCheck, Table as TableIcon, BarChart3 } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { OnboardingFunnel } from "@/types/metrics";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
  Cell,
} from "recharts";

interface OnboardingFunnelCardProps {
  data: OnboardingFunnel;
  isLoading?: boolean;
}

export function OnboardingFunnelCard({ data, isLoading = false }: OnboardingFunnelCardProps) {
  const [showTable, setShowTable] = useState(false);
  const { totalInvited, codePending, joined, expired, conversionRate } = data;

  const chartData = [
    { stage: "Invited", count: totalInvited, fill: "#295CB4" },
    { stage: "Code Pending", count: codePending, fill: "#F59E0B" },
    { stage: "Joined", count: joined, fill: "#10B981" },
    { stage: "Expired", count: expired, fill: "#6B7280" },
  ];

  const isEmpty = totalInvited === 0 && codePending === 0 && joined === 0;

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-emerald-500/10 p-1.5 text-emerald-400">
            <UserCheck className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Onboarding Funnel</CardTitle>
            <p className="text-xs text-muted-foreground">
              Conversion rate: <strong className="text-emerald-400">{conversionRate.toFixed(1)}%</strong>
            </p>
          </div>
        </div>

        <Button
          variant="ghost"
          size="sm"
          onClick={() => setShowTable(!showTable)}
          className="h-8 gap-1 text-xs text-muted-foreground"
          aria-label="Toggle view data as table"
        >
          {showTable ? <BarChart3 className="h-3.5 w-3.5" /> : <TableIcon className="h-3.5 w-3.5" />}
          <span>{showTable ? "Chart" : "Table"}</span>
        </Button>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="flex h-52 items-center justify-center">
            <div className="h-40 w-full animate-pulse rounded-lg bg-muted/30" />
          </div>
        ) : isEmpty ? (
          <div className="flex h-52 flex-col items-center justify-center text-center p-4 text-muted-foreground">
            <UserCheck className="h-8 w-8 stroke-1 text-muted-foreground/40 mb-2" />
            <p className="text-sm font-medium">No invitations recorded</p>
            <p className="text-xs text-muted-foreground/70 max-w-xs mt-1">
              Issue employee codes from the Onboarding tab to populate funnel metrics.
            </p>
          </div>
        ) : showTable ? (
          <div className="h-52 overflow-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Funnel Stage</TableHead>
                  <TableHead className="text-right">Staff Count</TableHead>
                  <TableHead className="text-right">% of Total</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {chartData.map((row) => (
                  <TableRow key={row.stage}>
                    <TableCell className="font-medium">{row.stage}</TableCell>
                    <TableCell className="text-right font-mono">{row.count}</TableCell>
                    <TableCell className="text-right font-mono text-muted-foreground">
                      {totalInvited > 0 ? ((row.count / totalInvited) * 100).toFixed(1) : "0.0"}%
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        ) : (
          <div className="h-52 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <XAxis dataKey="stage" tick={{ fill: "#A3A3A3", fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: "#A3A3A3", fontSize: 11 }} axisLine={false} tickLine={false} allowDecimals={false} />
                <RechartsTooltip
                  content={({ active, payload }) => {
                    if (active && payload && payload.length) {
                      const item = payload[0].payload;
                      return (
                        <div className="rounded-lg border border-border bg-card p-2 shadow-lg text-xs">
                          <p className="font-semibold text-foreground">{item.stage}</p>
                          <p className="text-muted-foreground">
                            Count: <strong className="text-foreground">{item.count}</strong>
                          </p>
                          <p className="text-muted-foreground">
                            Share:{" "}
                            <strong className="text-foreground">
                              {totalInvited > 0 ? ((item.count / totalInvited) * 100).toFixed(1) : 0}%
                            </strong>
                          </p>
                        </div>
                      );
                    }
                    return null;
                  }}
                />
                <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                  {chartData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.fill} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

