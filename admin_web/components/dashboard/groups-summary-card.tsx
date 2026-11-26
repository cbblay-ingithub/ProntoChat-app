"use client";

import React from "react";
import { FolderGit2, Building2, Briefcase } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { GroupsOverview } from "@/types/metrics";

interface GroupsSummaryCardProps {
  data: GroupsOverview;
  isLoading?: boolean;
}

export function GroupsSummaryCard({ data, isLoading = false }: GroupsSummaryCardProps) {
  const { activeDepartments, archivedDepartments, activeProjects, archivedProjects } = data;

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-primary/10 p-1.5 text-primary">
            <FolderGit2 className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Groups & Workspaces</CardTitle>
            <p className="text-xs text-muted-foreground">Active organizational units</p>
          </div>
        </div>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="grid grid-cols-2 gap-3">
            <div className="h-20 animate-pulse rounded-lg bg-muted/40" />
            <div className="h-20 animate-pulse rounded-lg bg-muted/40" />
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-3">
            {/* Departments */}
            <div className="rounded-lg border border-border/80 bg-muted/20 p-3">
              <div className="flex items-center space-x-1.5 text-muted-foreground text-xs">
                <Building2 className="h-3.5 w-3.5 text-blue-400" />
                <span className="font-medium">Departments</span>
              </div>
              <div className="mt-2 flex items-baseline space-x-2">
                <span className="text-2xl font-bold text-foreground">{activeDepartments}</span>
                {archivedDepartments > 0 && (
                  <span className="text-xs text-muted-foreground">({archivedDepartments} archived)</span>
                )}
              </div>
            </div>

            {/* Project Groups */}
            <div className="rounded-lg border border-border/80 bg-muted/20 p-3">
              <div className="flex items-center space-x-1.5 text-muted-foreground text-xs">
                <Briefcase className="h-3.5 w-3.5 text-purple-400" />
                <span className="font-medium">Project Groups</span>
              </div>
              <div className="mt-2 flex items-baseline space-x-2">
                <span className="text-2xl font-bold text-foreground">{activeProjects}</span>
                {archivedProjects > 0 && (
                  <span className="text-xs text-muted-foreground">({archivedProjects} archived)</span>
                )}
              </div>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

