"use client";

import React, { useState } from "react";
import { RefreshCw, LogOut, ShieldCheck, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { formatTimeLocal, formatUnambiguousDate } from "@/lib/format/date";
import { signOutAdmin } from "@/lib/firebase/auth";
import { Firm, Membership } from "@/types/firestore";

interface TopBarProps {
  firm: Firm | null;
  membership: Membership | null;
  adminName?: string;
  lastUpdated?: Date;
  onRefresh?: () => Promise<boolean | void>;
  isFetching?: boolean;
  isThrottled?: boolean;
}

export function TopBar({
  firm,
  membership,
  adminName = "Administrator",
  lastUpdated,
  onRefresh,
  isFetching = false,
  isThrottled = false,
}: TopBarProps) {
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false);

  const handleRefreshClick = async () => {
    if (onRefresh && !isRefreshing && !isFetching) {
      setIsRefreshing(true);
      await onRefresh();
      setIsRefreshing(false);
    }
  };

  const handleSignOut = async () => {
    if (confirm("Signing out will end your session for both the Admin Console and the Messaging app. Continue?")) {
      await signOutAdmin();
      window.location.href = "/admin/sign-in/";
    }
  };

  const planLabel = (firm?.plan || "Trial").toUpperCase();
  const createdAtFormatted = firm?.createdAt ? formatUnambiguousDate(firm.createdAt) : "—";

  return (
    <header className="border-b border-border bg-card/60 backdrop-blur-md">
      {/* Upper Navigation Strip */}
      <div className="flex h-16 items-center justify-between px-4 sm:px-6 lg:px-8">
        <div className="flex items-center space-x-3 pl-12 md:pl-0">
          <h1 className="text-xl font-bold tracking-tight text-foreground">Dashboard</h1>
          <Badge variant="outline" className="hidden sm:inline-flex border-primary/30 bg-primary/10 text-primary font-medium text-xs">
            {planLabel} PLAN
          </Badge>
        </div>

        {/* Action Controls & User Menu */}
        <div className="flex items-center space-x-3">
          {/* Refresh Control */}
          <div className="flex items-center space-x-2">
            <span className="hidden text-xs text-muted-foreground sm:inline-block">
              {lastUpdated ? `Updated ${formatTimeLocal(lastUpdated)}` : "Updating..."}
            </span>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleRefreshClick}
                  disabled={isRefreshing || isFetching || isThrottled}
                  className="h-8 gap-1.5 border-border bg-card text-xs font-medium text-muted-foreground hover:text-foreground"
                >
                  <RefreshCw
                    className={`h-3.5 w-3.5 ${isRefreshing || isFetching ? "animate-spin text-primary" : ""}`}
                  />
                  <span className="hidden md:inline">Refresh</span>
                </Button>
              </TooltipTrigger>
              <TooltipContent side="bottom">
                {isThrottled
                  ? "Refresh throttled (30s cooldown between live queries)"
                  : "Fetch fresh metrics from Firestore"}
              </TooltipContent>
            </Tooltip>
          </div>

          {/* User Menu Dropdown */}
          <div className="relative">
            <button
              onClick={() => setIsUserMenuOpen(!isUserMenuOpen)}
              className="flex items-center space-x-2 rounded-full border border-border bg-card/80 p-1.5 pl-2.5 transition-colors hover:border-primary/40 focus:outline-none focus:ring-2 focus:ring-primary/40"
              aria-label="User account menu"
            >
              <div className="flex flex-col text-right">
                <span className="text-xs font-semibold leading-tight text-foreground max-w-[120px] truncate">
                  {adminName}
                </span>
                <span className="text-[10px] text-muted-foreground leading-tight">
                  {membership?.role || "Admin"}
                </span>
              </div>
              <div className="flex h-7 w-7 items-center justify-center rounded-full bg-primary/15 text-primary text-xs font-bold">
                {adminName[0]?.toUpperCase() || "A"}
              </div>
            </button>

            {/* Dropdown Popover */}
            {isUserMenuOpen && (
              <>
                <div
                  className="fixed inset-0 z-30"
                  onClick={() => setIsUserMenuOpen(false)}
                />
                <div className="absolute right-0 top-11 z-40 w-64 rounded-xl border border-border bg-card p-2 shadow-xl animate-in fade-in-0 zoom-in-95">
                  <div className="border-b border-border px-3 py-2 text-xs">
                    <p className="font-semibold text-foreground truncate">{adminName}</p>
                    <p className="text-muted-foreground truncate">{membership?.email || ""}</p>
                    <div className="mt-1.5 flex items-center space-x-1.5 text-primary text-[11px]">
                      <ShieldCheck className="h-3.5 w-3.5" />
                      <span className="capitalize">{membership?.role || "Admin"} Access</span>
                    </div>
                  </div>

                  <div className="py-1">
                    <div className="px-3 py-1.5 text-[11px] text-muted-foreground">
                      <span>Organization: </span>
                      <strong className="text-foreground">{firm?.name || "ProntoChat"}</strong>
                    </div>
                  </div>

                  <div className="border-t border-border pt-1">
                    <button
                      onClick={handleSignOut}
                      className="flex w-full items-center space-x-2 rounded-lg px-3 py-2 text-xs text-destructive hover:bg-destructive/10 transition-colors"
                    >
                      <LogOut className="h-3.5 w-3.5" />
                      <span>Sign out (shared session)</span>
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Header Context Strip */}
      <div className="bg-muted/20 px-4 py-2.5 sm:px-6 lg:px-8 border-t border-border/50">
        <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-muted-foreground">
          <div className="flex items-center space-x-2">
            <span className="font-medium text-foreground">Welcome back, {adminName}.</span>
            <span>Firm established on <strong className="text-foreground">{createdAtFormatted}</strong>.</span>
          </div>

          <div className="flex items-center space-x-3">
            <span className="flex items-center space-x-1.5">
              <span className="h-2 w-2 rounded-full bg-primary animate-pulse" />
              <span>Read-only Mode Active</span>
            </span>
          </div>
        </div>
      </div>
    </header>
  );
}

