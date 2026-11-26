"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { subscribeToAuthState } from "@/lib/firebase/auth";

export default function AdminRootPage() {
  const router = useRouter();

  useEffect(() => {
    const unsubscribe = subscribeToAuthState((user) => {
      if (user) {
        router.replace("/dashboard/");
      } else {
        router.replace("/sign-in/");
      }
    });

    return () => unsubscribe();
  }, [router]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
    </div>
  );
}

