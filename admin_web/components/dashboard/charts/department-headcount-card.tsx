"use client";

import React, { useState } from "react";
import { Building2, Table as TableIcon, BarChart3 } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { DepartmentBreakdown } from "@/types/metrics";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
  Cell,
} from "recharts";

interface DepartmentHeadcountCardProps {
  data: DepartmentBreakdown;
  isLoading?: boolean;
}

const PALETTE = ["#10B981", "#295CB4", "#8B5CF6", "#F59E0B", "#EC4899", "#06B6D4", "#64748B"];

export function DepartmentHeadcountCard({ data, isLoading = false }: DepartmentHeadcountCardProps) {
  const [showTable, setShowTable] = useState(false);
  const { departments, unassignedCount } = data;

  const chartData = [
    ...departments.map((d, i) => ({
      name: d.name,
      count: d.count,
      fill: PALETTE[i % PALETTE.length],
    })),
    ...(unassignedCount > 0
      ? [{ name: "No department", count: unassignedCount, fill: "#64748B" }]
      : []),
  ];

  const totalHeadcount = chartData.reduce((sum, item) => sum + item.count, 0);
  const isEmpty = chartData.length === 0 || totalHeadcount === 0;

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-blue-500/10 p-1.5 text-blue-400">
            <Building2 className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Department Headcount</CardTitle>
            <p className="text-xs text-muted-foreground">Active members per department</p>
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
            <Building2 className="h-8 w-8 stroke-1 text-muted-foreground/40 mb-2" />
            <p className="text-sm font-medium">No departments or active staff</p>
            <p className="text-xs text-muted-foreground/70 max-w-xs mt-1">
              Create departments or onboard employees to view team distribution.
            </p>
          </div>
        ) : showTable ? (
          <div className="h-52 overflow-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Department</TableHead>
                  <TableHead className="text-right">Active Staff</TableHead>
                  <TableHead className="text-right">Share</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {chartData.map((row) => (
                  <TableRow key={row.name}>
                    <TableCell className="font-medium">{row.name}</TableCell>
                    <TableCell className="text-right font-mono">{row.count}</TableCell>
                    <TableCell className="text-right font-mono text-muted-foreground">
                      {totalHeadcount > 0 ? ((row.count / totalHeadcount) * 100).toFixed(1) : "0.0"}%
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        ) : (
          <div className="h-52 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={chartData}
                layout="vertical"
                margin={{ top: 5, right: 20, left: 20, bottom: 5 }}
              >
                <XAxis type="number" tick={{ fill: "#A3A3A3", fontSize: 11 }} axisLine={false} tickLine={false} allowDecimals={false} />
                <YAxis
                  dataKey="name"
                  type="category"
                  tick={{ fill: "#A3A3A3", fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                  width={90}
                />
                <RechartsTooltip
                  content={({ active, payload }) => {
                    if (active && payload && payload.length) {
                      const item = payload[0].payload;
                      return (
                        <div className="rounded-lg border border-border bg-card p-2 shadow-lg text-xs">
                          <p className="font-semibold text-foreground">{item.name}</p>
                          <p className="text-muted-foreground">
                            Active staff: <strong className="text-foreground">{item.count}</strong>
                          </p>
                          <p className="text-muted-foreground">
                            Share:{" "}
                            <strong className="text-foreground">
                              {totalHeadcount > 0 ? ((item.count / totalHeadcount) * 100).toFixed(1) : 0}%
                            </strong>
                          </p>
                        </div>
                      );
                    }
                    return null;
                  }}
                />
                <Bar dataKey="count" radius={[0, 4, 4, 0]}>
                  {chartData.map((entry, index) => (
                    <Cell key={`dept-${index}`} fill={entry.fill} />
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

