"use client";

import React, { useState } from "react";
import { Shield, Table as TableIcon, PieChart as PieChartIcon } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { RoleDistribution } from "@/types/metrics";
import {
  PieChart,
  Pie,
  Cell,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
} from "recharts";

interface RoleDistributionCardProps {
  data: RoleDistribution;
  isLoading?: boolean;
}

const ROLES_CONFIG = [
  { key: "admin", label: "Administrators", color: "#8B5CF6" },
  { key: "lead", label: "Department Leads", color: "#295CB4" },
  { key: "employee", label: "Staff Members", color: "#10B981" },
];

export function RoleDistributionCard({ data, isLoading = false }: RoleDistributionCardProps) {
  const [showTable, setShowTable] = useState(false);
  const { adminCount, leadCount, employeeCount, total } = data;

  const chartData = [
    { name: "Administrators", count: adminCount, fill: "#8B5CF6" },
    { name: "Department Leads", count: leadCount, fill: "#295CB4" },
    { name: "Staff Members", count: employeeCount, fill: "#10B981" },
  ].filter((item) => item.count > 0);

  const isEmpty = total === 0;

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-purple-500/10 p-1.5 text-purple-400">
            <Shield className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Role Split</CardTitle>
            <p className="text-xs text-muted-foreground">{total} total active team members</p>
          </div>
        </div>

        <Button
          variant="ghost"
          size="sm"
          onClick={() => setShowTable(!showTable)}
          className="h-8 gap-1 text-xs text-muted-foreground"
          aria-label="Toggle view data as table"
        >
          {showTable ? <PieChartIcon className="h-3.5 w-3.5" /> : <TableIcon className="h-3.5 w-3.5" />}
          <span>{showTable ? "Chart" : "Table"}</span>
        </Button>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="flex h-52 items-center justify-center">
            <div className="h-36 w-36 animate-pulse rounded-full bg-muted/30" />
          </div>
        ) : isEmpty ? (
          <div className="flex h-52 flex-col items-center justify-center text-center p-4 text-muted-foreground">
            <Shield className="h-8 w-8 stroke-1 text-muted-foreground/40 mb-2" />
            <p className="text-sm font-medium">No roles assigned</p>
            <p className="text-xs text-muted-foreground/70 max-w-xs mt-1">
              Active members will appear categorized by permission level.
            </p>
          </div>
        ) : showTable ? (
          <div className="h-52 overflow-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Role</TableHead>
                  <TableHead className="text-right">Staff</TableHead>
                  <TableHead className="text-right">Percentage</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {ROLES_CONFIG.map((role) => {
                  const count =
                    role.key === "admin"
                      ? adminCount
                      : role.key === "lead"
                      ? leadCount
                      : employeeCount;
                  return (
                    <TableRow key={role.key}>
                      <TableCell className="font-medium flex items-center space-x-2">
                        <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: role.color }} />
                        <span>{role.label}</span>
                      </TableCell>
                      <TableCell className="text-right font-mono">{count}</TableCell>
                      <TableCell className="text-right font-mono text-muted-foreground">
                        {total > 0 ? ((count / total) * 100).toFixed(1) : "0.0"}%
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        ) : (
          <div className="flex h-52 items-center justify-between">
            <div className="h-full w-1/2">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <RechartsTooltip
                    content={({ active, payload }) => {
                      if (active && payload && payload.length) {
                        const item = payload[0].payload;
                        return (
                          <div className="rounded-lg border border-border bg-card p-2 shadow-lg text-xs">
                            <p className="font-semibold text-foreground">{item.name}</p>
                            <p className="text-muted-foreground">
                              Count: <strong className="text-foreground">{item.count}</strong>
                            </p>
                            <p className="text-muted-foreground">
                              Share:{" "}
                              <strong className="text-foreground">
                                {total > 0 ? ((item.count / total) * 100).toFixed(1) : 0}%
                              </strong>
                            </p>
                          </div>
                        );
                      }
                      return null;
                    }}
                  />
                  <Pie
                    data={chartData}
                    dataKey="count"
                    nameKey="name"
                    innerRadius={45}
                    outerRadius={65}
                    paddingAngle={3}
                  >
                    {chartData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.fill} />
                    ))}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
            </div>

            {/* Custom accessible legend */}
            <div className="flex w-1/2 flex-col space-y-2 pr-2 text-xs">
              {ROLES_CONFIG.map((role) => {
                const count =
                  role.key === "admin"
                    ? adminCount
                    : role.key === "lead"
                    ? leadCount
                    : employeeCount;
                const pct = total > 0 ? ((count / total) * 100).toFixed(0) : "0";
                return (
                  <div key={role.key} className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <span className="h-2 w-2 rounded-full" style={{ backgroundColor: role.color }} />
                      <span className="text-muted-foreground truncate">{role.label}</span>
                    </div>
                    <div className="font-mono text-foreground font-semibold">
                      {count} <span className="text-muted-foreground font-normal text-[11px]">({pct}%)</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

