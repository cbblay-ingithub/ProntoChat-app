"use client";

import React from "react";
import {
  AlertTriangle,
  Clock,
  UserX,
  Building,
  ShieldAlert,
  ChevronRight,
  CheckCircle2,
} from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { NeedsAttentionItem, NeedsAttentionType } from "@/types/metrics";
import { cn } from "@/lib/utils";

interface NeedsAttentionCardProps {
  items: NeedsAttentionItem[];
  isLoading?: boolean;
}

export function NeedsAttentionCard({ items, isLoading = false }: NeedsAttentionCardProps) {
  const getIconForType = (type: NeedsAttentionType) => {
    switch (type) {
      case "expiringCode":
        return <Clock className="h-4 w-4 text-amber-400" />;
      case "staleInvite":
        return <UserX className="h-4 w-4 text-amber-400" />;
      case "departmentNoHead":
        return <Building className="h-4 w-4 text-blue-400" />;
      case "departmentZeroStaff":
        return <Building className="h-4 w-4 text-rose-400" />;
      case "projectRevokedOwner":
        return <ShieldAlert className="h-4 w-4 text-rose-400" />;
      default:
        return <AlertTriangle className="h-4 w-4 text-amber-400" />;
    }
  };

  const getBadgeColor = (type: NeedsAttentionType) => {
    switch (type) {
      case "projectRevokedOwner":
      case "departmentZeroStaff":
        return "destructive";
      default:
        return "warning";
    }
  };

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <div className="flex items-center space-x-2">
          <div className="rounded-lg bg-amber-500/10 p-1.5 text-amber-400">
            <AlertTriangle className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold">Needs Attention</CardTitle>
            <p className="text-xs text-muted-foreground">Operational bottlenecks and audit triggers</p>
          </div>
        </div>

        <Badge
          variant={items.length > 0 ? "warning" : "default"}
          className="text-xs font-semibold"
        >
          {items.length} {items.length === 1 ? "Item" : "Items"}
        </Badge>
      </CardHeader>

      <CardContent className="pt-2">
        {isLoading ? (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-12 w-full animate-pulse rounded-lg bg-muted/40" />
            ))}
          </div>
        ) : items.length === 0 ? (
          <div className="flex h-44 flex-col items-center justify-center text-center p-4 text-muted-foreground">
            <CheckCircle2 className="h-8 w-8 text-emerald-400 mb-2 stroke-1" />
            <p className="text-sm font-medium text-foreground">All clear</p>
            <p className="text-xs text-muted-foreground max-w-xs mt-1">
              No expiring codes, unstaffed departments, or orphan project groups detected.
            </p>
          </div>
        ) : (
          <div className="divide-y divide-border/60">
            {items.slice(0, 5).map((item) => (
              <a
                key={item.id}
                href={item.route}
                className="group flex items-center justify-between py-3 transition-colors hover:bg-muted/30 px-2 rounded-lg"
              >
                <div className="flex items-start space-x-3">
                  <div className="mt-0.5 rounded-md bg-muted/60 p-1.5 shrink-0">
                    {getIconForType(item.type)}
                  </div>
                  <div>
                    <div className="flex items-center space-x-2">
                      <span className="text-xs font-semibold text-foreground group-hover:text-primary transition-colors">
                        {item.title}
                      </span>
                      <Badge variant="outline" className="text-[9px] py-0 px-1 border-border/60">
                        Legacy
                      </Badge>
                    </div>
                    <p className="text-[11px] text-muted-foreground line-clamp-1 mt-0.5">
                      {item.subtitle}
                    </p>
                  </div>
                </div>

                <div className="flex items-center text-muted-foreground group-hover:text-primary transition-colors pl-2">
                  <ChevronRight className="h-4 w-4" />
                </div>
              </a>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

