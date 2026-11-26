"use client";

import React, { useState } from "react";
import { UserPlus, Building, BellPlus, Link2, Check, ExternalLink } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";

interface QuickActionsProps {
  firmId?: string;
}

export function QuickActions({ firmId }: QuickActionsProps) {
  const [copied, setCopied] = useState(false);

  const handleCopyLink = () => {
    if (!firmId) return;
    const origin = typeof window !== "undefined" ? window.location.origin : "";
    const joinUrl = `${origin}/#/join?firmId=${firmId}`;
    navigator.clipboard.writeText(joinUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <Card className="transition-all hover:shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold">Quick Actions</CardTitle>
      </CardHeader>

      <CardContent>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
          {/* Add Staff Link */}
          <a
            href="/#/admin/onboarding?action=add"
            className="flex flex-col items-center justify-center rounded-lg border border-border/80 bg-muted/20 p-3 text-center transition-all hover:bg-muted/60 hover:border-primary/40 group"
          >
            <div className="rounded-lg bg-primary/10 p-2 text-primary group-hover:scale-110 transition-transform">
              <UserPlus className="h-4 w-4" />
            </div>
            <span className="mt-2 text-xs font-semibold text-foreground">Add staff</span>
            <div className="mt-1 flex items-center space-x-1">
              <Badge variant="outline" className="text-[9px] py-0 px-1 border-border/60">Legacy</Badge>
              <ExternalLink className="h-2.5 w-2.5 text-muted-foreground" />
            </div>
          </a>

          {/* New Department Link */}
          <a
            href="/#/admin/notices?action=new-dept"
            className="flex flex-col items-center justify-center rounded-lg border border-border/80 bg-muted/20 p-3 text-center transition-all hover:bg-muted/60 hover:border-primary/40 group"
          >
            <div className="rounded-lg bg-blue-500/10 p-2 text-blue-400 group-hover:scale-110 transition-transform">
              <Building className="h-4 w-4" />
            </div>
            <span className="mt-2 text-xs font-semibold text-foreground">New department</span>
            <div className="mt-1 flex items-center space-x-1">
              <Badge variant="outline" className="text-[9px] py-0 px-1 border-border/60">Legacy</Badge>
              <ExternalLink className="h-2.5 w-2.5 text-muted-foreground" />
            </div>
          </a>

          {/* New Notice Link */}
          <a
            href="/#/admin/notices?action=new-notice"
            className="flex flex-col items-center justify-center rounded-lg border border-border/80 bg-muted/20 p-3 text-center transition-all hover:bg-muted/60 hover:border-primary/40 group"
          >
            <div className="rounded-lg bg-purple-500/10 p-2 text-purple-400 group-hover:scale-110 transition-transform">
              <BellPlus className="h-4 w-4" />
            </div>
            <span className="mt-2 text-xs font-semibold text-foreground">New notice</span>
            <div className="mt-1 flex items-center space-x-1">
              <Badge variant="outline" className="text-[9px] py-0 px-1 border-border/60">Legacy</Badge>
              <ExternalLink className="h-2.5 w-2.5 text-muted-foreground" />
            </div>
          </a>

          {/* Copy Join Link (Zero-write client operation) */}
          <button
            onClick={handleCopyLink}
            disabled={!firmId}
            className="flex flex-col items-center justify-center rounded-lg border border-border/80 bg-muted/20 p-3 text-center transition-all hover:bg-muted/60 hover:border-primary/40 group cursor-pointer"
          >
            <div className="rounded-lg bg-emerald-500/10 p-2 text-emerald-400 group-hover:scale-110 transition-transform">
              {copied ? <Check className="h-4 w-4 text-emerald-400" /> : <Link2 className="h-4 w-4" />}
            </div>
            <span className="mt-2 text-xs font-semibold text-foreground">
              {copied ? "Link Copied!" : "Copy join link"}
            </span>
            <span className="mt-1 text-[10px] text-muted-foreground">Client clipboard</span>
          </button>
        </div>
      </CardContent>
    </Card>
  );
}

