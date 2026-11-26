"use client";

import React, { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Mail, Lock, AlertCircle, ArrowRight, ShieldCheck } from "lucide-react";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { signInAdmin, resolveAdminSession, subscribeToAuthState } from "@/lib/firebase/auth";

export default function SignInPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Check if already signed in
  useEffect(() => {
    const unsubscribe = subscribeToAuthState(async (user) => {
      if (user) {
        setIsLoading(true);
        const session = await resolveAdminSession(user);
        if (session.isAdmin) {
          router.replace("/dashboard/");
        } else {
          // Non-admin signed in
          setErrorMessage("Your account does not have administrative privileges for this organization.");
          setIsLoading(false);
        }
      }
    });

    return () => unsubscribe();
  }, [router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setErrorMessage("Please enter both email and password.");
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);

    try {
      const user = await signInAdmin(email, password);
      const session = await resolveAdminSession(user);

      if (session.isRevoked) {
        setErrorMessage("Access has been revoked by your organization administrator.");
        setIsLoading(false);
        return;
      }

      if (session.isFirmSuspended) {
        setErrorMessage("This workspace has been suspended due to platform policy review.");
        setIsLoading(false);
        return;
      }

      if (!session.isAdmin) {
        // Redirect non-admins to the employee messaging interface per prompt specification
        window.location.href = "/#/home";
        return;
      }

      router.replace("/dashboard/");
    } catch (err: any) {
      console.error("[SignIn] Error:", err);
      let msg = "Invalid email or password.";
      if (err.code === "auth/user-not-found" || err.code === "auth/wrong-password" || err.code === "auth/invalid-credential") {
        msg = "Invalid email address or password.";
      } else if (err.code === "auth/too-many-requests") {
        msg = "Too many failed attempts. Please try again in a few minutes.";
      } else if (err.message) {
        msg = err.message;
      }
      setErrorMessage(msg);
      setIsLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-4 bg-background">
      <div className="w-full max-w-md space-y-6">
        {/* Branding header */}
        <div className="flex flex-col items-center text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-primary/10 border border-primary/30 text-primary mb-3">
            <ShieldCheck className="h-7 w-7" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">ProntoChat Admin</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Enterprise administration console & team analytics
          </p>
        </div>

        {/* Card Form */}
        <Card className="border-border/80 shadow-2xl">
          <form onSubmit={handleSubmit}>
            <CardHeader className="space-y-1">
              <CardTitle className="text-lg">Sign In</CardTitle>
              <CardDescription>
                Sign in with your organization administrator credentials
              </CardDescription>
            </CardHeader>

            <CardContent className="space-y-4">
              {errorMessage && (
                <div className="flex items-start space-x-2 rounded-lg border border-destructive/40 bg-destructive/10 p-3 text-xs text-destructive">
                  <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
                  <span>{errorMessage}</span>
                </div>
              )}

              <div className="space-y-2">
                <label className="text-xs font-medium text-foreground" htmlFor="email">
                  Work Email
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
                  <input
                    id="email"
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="admin@company.com"
                    className="w-full rounded-lg border border-border bg-muted/30 px-3 py-2 pl-9 text-sm text-foreground placeholder:text-muted-foreground/60 focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                    disabled={isLoading}
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-xs font-medium text-foreground" htmlFor="password">
                  Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
                  <input
                    id="password"
                    type="password"
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    className="w-full rounded-lg border border-border bg-muted/30 px-3 py-2 pl-9 text-sm text-foreground placeholder:text-muted-foreground/60 focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                    disabled={isLoading}
                  />
                </div>
              </div>
            </CardContent>

            <CardFooter className="flex flex-col space-y-3">
              <Button
                type="submit"
                disabled={isLoading}
                className="w-full font-semibold gap-1.5"
              >
                {isLoading ? "Signing in..." : "Continue to Dashboard"}
                {!isLoading && <ArrowRight className="h-4 w-4" />}
              </Button>

              <div className="text-center text-xs text-muted-foreground">
                Looking for employee messaging?{" "}
                <a href="/#/home" className="text-primary hover:underline font-medium">
                  Open Flutter Chat
                </a>
              </div>
            </CardFooter>
          </form>
        </Card>

        {/* Security & Sandbox notice */}
        <p className="text-center text-[11px] text-muted-foreground/60">
          Shared Firebase Auth session across web apps. Read-only prototype mode.
        </p>
      </div>
    </div>
  );
}

