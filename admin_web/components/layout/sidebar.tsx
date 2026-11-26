"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  UserPlus,
  BellRing,
  Palette,
  MessageSquare,
  ChevronLeft,
  ChevronRight,
  Menu,
  X,
  ExternalLink,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { Badge } from "@/components/ui/badge";
import { resolveLogoUrl } from "@/lib/format/cloudinary";
import { Firm } from "@/types/firestore";

interface SidebarProps {
  firm: Firm | null;
  onToggleCollapse?: (collapsed: boolean) => void;
}

export function Sidebar({ firm, onToggleCollapse }: SidebarProps) {
  const pathname = usePathname();
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [isMobileOpen, setIsMobileOpen] = useState(false);

  // Load persisted collapse state safely from guarded localStorage
  useEffect(() => {
    try {
      const stored = localStorage.getItem("prontochat_admin_sidebar_collapsed");
      if (stored !== null) {
        const val = stored === "true";
        setIsCollapsed(val);
        onToggleCollapse?.(val);
      }
    } catch {
      // Guarded localStorage access
    }
  }, [onToggleCollapse]);

  const toggleCollapse = () => {
    const next = !isCollapsed;
    setIsCollapsed(next);
    onToggleCollapse?.(next);
    try {
      localStorage.setItem("prontochat_admin_sidebar_collapsed", String(next));
    } catch {
      // Guarded
    }
  };

  // Nav items configuration
  const navItems = [
    {
      title: "Dashboard",
      icon: LayoutDashboard,
      href: "/dashboard/",
      isCurrent: true,
      legacy: false,
    },
    {
      title: "Onboarding",
      icon: UserPlus,
      href: "/#/admin/onboarding",
      isCurrent: false,
      legacy: true,
    },
    {
      title: "Notices & Groups",
      icon: BellRing,
      href: "/#/admin/notices",
      isCurrent: false,
      legacy: true,
    },
    {
      title: "Customization",
      icon: Palette,
      href: "/#/admin/brand",
      isCurrent: false,
      legacy: true,
    },
  ];

  const logoUrl = firm ? resolveLogoUrl(firm.logo, firm.logoUrl, "logo_sm") : null;
  const firmName = firm?.name || "ProntoChat";
  const initials = firmName
    .split(" ")
    .map((n) => n[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <>
      {/* Mobile Toggle Button (Fixed on top left) */}
      <button
        onClick={() => setIsMobileOpen(true)}
        className="fixed top-3 left-4 z-40 rounded-lg border border-border bg-card p-2 text-foreground md:hidden"
        aria-label="Open sidebar"
      >
        <Menu className="h-5 w-5" />
      </button>

      {/* Off-canvas Backdrop for Mobile */}
      {isMobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm md:hidden"
          onClick={() => setIsMobileOpen(false)}
        />
      )}

      {/* Sidebar Container */}
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-40 flex flex-col border-r border-border bg-card transition-all duration-300 ease-in-out md:static",
          isCollapsed ? "w-20" : "w-64",
          isMobileOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"
        )}
      >
        {/* Top Firm Identity Strip */}
        <div className="flex h-16 items-center justify-between border-b border-border px-4">
          <div className="flex items-center space-x-3 overflow-hidden">
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10 border border-primary/30 text-primary font-bold text-sm">
              {logoUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={logoUrl}
                  alt={firmName}
                  className="h-full w-full rounded-lg object-cover"
                />
              ) : (
                <span>{initials}</span>
              )}
            </div>
            {!isCollapsed && (
              <div className="flex flex-col overflow-hidden">
                <span className="truncate text-sm font-semibold text-foreground">
                  {firmName}
                </span>
                <span className="text-[11px] font-medium text-muted-foreground uppercase tracking-wider">
                  Admin Console
                </span>
              </div>
            )}
          </div>

          {/* Close button for mobile */}
          <button
            onClick={() => setIsMobileOpen(false)}
            className="rounded p-1 text-muted-foreground hover:text-foreground md:hidden"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Navigation Items */}
        <nav className="flex-1 space-y-1.5 px-3 py-4">
          <div className={cn("px-2 pb-1 text-[11px] font-medium tracking-wider text-muted-foreground uppercase", isCollapsed && "sr-only")}>
            Administration
          </div>

          {navItems.map((item) => {
            const isActive = item.isCurrent && (pathname === "/dashboard" || pathname === "/dashboard/");
            const Icon = item.icon;

            const buttonContent = (
              <div
                className={cn(
                  "relative flex items-center rounded-lg px-3 py-2.5 text-sm font-medium transition-all group",
                  isActive
                    ? "bg-primary/15 text-primary font-semibold"
                    : "text-muted-foreground hover:bg-muted/60 hover:text-foreground"
                )}
              >
                {/* Sliding active indicator bar */}
                {isActive && (
                  <span className="absolute left-0 top-1.5 bottom-1.5 w-1 rounded-r-full bg-primary" />
                )}
                <Icon className={cn("h-5 w-5 shrink-0 transition-transform group-hover:scale-105", isActive && "text-primary")} />

                {!isCollapsed && (
                  <div className="ml-3 flex flex-1 items-center justify-between">
                    <span>{item.title}</span>
                    {item.legacy && (
                      <Badge variant="outline" className="text-[10px] font-normal py-0 px-1.5 text-muted-foreground border-border/80">
                        Legacy
                      </Badge>
                    )}
                  </div>
                )}
              </div>
            );

            if (isCollapsed) {
              return (
                <Tooltip key={item.title}>
                  <TooltipTrigger asChild>
                    {item.legacy ? (
                      <a href={item.href} className="block">
                        {buttonContent}
                      </a>
                    ) : (
                      <Link href={item.href} className="block">
                        {buttonContent}
                      </Link>
                    )}
                  </TooltipTrigger>
                  <TooltipContent side="right">
                    <span>{item.title}</span>
                    {item.legacy && <span className="ml-1 text-[10px] text-muted-foreground">(Legacy)</span>}
                  </TooltipContent>
                </Tooltip>
              );
            }

            return item.legacy ? (
              <a key={item.title} href={item.href} className="block">
                {buttonContent}
              </a>
            ) : (
              <Link key={item.title} href={item.href} className="block">
                {buttonContent}
              </Link>
            );
          })}

          <div className="pt-4">
            <div className={cn("px-2 pb-1 text-[11px] font-medium tracking-wider text-muted-foreground uppercase", isCollapsed && "sr-only")}>
              Employee App
            </div>
            {/* Open Messaging Link */}
            {isCollapsed ? (
              <Tooltip>
                <TooltipTrigger asChild>
                  <a
                    href="/#/home"
                    className="flex items-center rounded-lg px-3 py-2.5 text-sm font-medium text-muted-foreground transition-all hover:bg-muted/60 hover:text-foreground"
                  >
                    <MessageSquare className="h-5 w-5 shrink-0" />
                  </a>
                </TooltipTrigger>
                <TooltipContent side="right">
                  Open Messaging App
                </TooltipContent>
              </Tooltip>
            ) : (
              <a
                href="/#/home"
                className="flex items-center justify-between rounded-lg px-3 py-2.5 text-sm font-medium text-muted-foreground transition-all hover:bg-muted/60 hover:text-foreground"
              >
                <div className="flex items-center space-x-3">
                  <MessageSquare className="h-5 w-5 shrink-0" />
                  <span>Open messaging</span>
                </div>
                <ExternalLink className="h-3.5 w-3.5 opacity-60" />
              </a>
            )}
          </div>
        </nav>

        {/* Bottom Collapse Toggle (Desktop only) */}
        <div className="hidden border-t border-border p-3 md:block">
          <button
            onClick={toggleCollapse}
            className="flex w-full items-center justify-center rounded-lg border border-border/60 py-2 text-xs font-medium text-muted-foreground transition-colors hover:bg-muted/50 hover:text-foreground"
            aria-label={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
          >
            {isCollapsed ? (
              <ChevronRight className="h-4 w-4" />
            ) : (
              <div className="flex items-center space-x-2">
                <ChevronLeft className="h-4 w-4" />
                <span>Collapse menu</span>
              </div>
            )}
          </button>
        </div>
      </aside>
    </>
  );
}

