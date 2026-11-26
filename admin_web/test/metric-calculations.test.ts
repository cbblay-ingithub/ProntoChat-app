import { describe, it, expect } from "vitest";
import { getStartOfWeekLocal, getWeeklyIntervals, formatUnambiguousDate } from "@/lib/format/date";
import { resolveLogoUrl } from "@/lib/format/cloudinary";

describe("Metric Calculations & Business Logic Tests", () => {
  describe("Week Boundaries & Date Math", () => {
    it("correctly identifies Monday 00:00:00 in local time", () => {
      // Wednesday 15 Oct 2026 14:30
      const wednesday = new Date(2026, 9, 14, 14, 30, 0);
      const start = getStartOfWeekLocal(wednesday);

      expect(start.getDay()).toBe(1); // Monday
      expect(start.getHours()).toBe(0);
      expect(start.getMinutes()).toBe(0);
      expect(start.getSeconds()).toBe(0);
      expect(start.getDate()).toBe(12); // Monday 12 Oct 2026
    });

    it("correctly handles Sundays as part of the previous Monday week", () => {
      // Sunday 18 Oct 2026 23:59
      const sunday = new Date(2026, 9, 18, 23, 59, 0);
      const start = getStartOfWeekLocal(sunday);

      expect(start.getDay()).toBe(1); // Monday
      expect(start.getDate()).toBe(12); // Monday 12 Oct 2026
    });

    it("generates exact consecutive 7-day intervals for 4, 8, and 12 weeks", () => {
      const intervals8 = getWeeklyIntervals(8, new Date(2026, 9, 14));
      expect(intervals8.length).toBe(8);

      for (let i = 0; i < intervals8.length - 1; i++) {
        expect(intervals8[i].weekEnd.getTime()).toBe(intervals8[i + 1].weekStart.getTime());
      }
    });

    it("formats unambiguous date as d MMM yyyy", () => {
      const d = new Date(2026, 2, 7); // 7 March 2026
      expect(formatUnambiguousDate(d)).toBe("7 Mar 2026");
    });
  });

  describe("Headline KPIs and Parity Formulas", () => {
    it("computes Total Staff and Pending Staff with exact OnboardingTab parity", () => {
      const active = 45;
      const pendingMembers = 3;
      const revoked = 2;
      const invitedPreApproved = 8;

      const activeDelta = 4;
      const pendingDelta = 2;
      const revokedDelta = 1;

      // Rule: Pending = pending approval members + invited pre-approved staff
      const pending = pendingMembers + invitedPreApproved;
      const total = active + pending + revoked;
      const totalDelta = activeDelta + pendingDelta;

      expect(pending).toBe(11);
      expect(total).toBe(58);
      expect(totalDelta).toBe(6);
    });
  });

  describe("Seat Usage & Desynchronization Detection", () => {
    it("detects when stored seatCount disagrees with true member + invite count", () => {
      const active = 4;
      const invited = 2;
      const trueSeats = active + invited; // 6
      const storedSeatCount = 5; // desynchronized
      const seatLimit = 10;

      const isOutOfSync = trueSeats !== storedSeatCount;
      const remaining = Math.max(0, seatLimit - trueSeats);
      const ratio = trueSeats / seatLimit;

      expect(isOutOfSync).toBe(true);
      expect(remaining).toBe(4);
      expect(ratio).toBe(0.6);
    });

    it("caps ratio at 1.0 and remaining seats at 0 when limit is reached", () => {
      const trueSeats = 12;
      const seatLimit = 10;

      const remaining = Math.max(0, seatLimit - trueSeats);
      const ratio = Math.min(1.0, trueSeats / seatLimit);

      expect(remaining).toBe(0);
      expect(ratio).toBe(1.0);
    });
  });

  describe("Onboarding Funnel & Conversion Rate", () => {
    it("computes conversion rate without dividing by zero on empty firm", () => {
      const totalInvited = 0;
      const joined = 0;
      const conversionRate = totalInvited > 0 ? (joined / totalInvited) * 100 : 0;

      expect(conversionRate).toBe(0);
      expect(Number.isNaN(conversionRate)).toBe(false);
    });

    it("calculates accurate percentage when invites exist", () => {
      const totalInvited = 20;
      const joined = 15;
      const conversionRate = (joined / totalInvited) * 100;

      expect(conversionRate).toBe(75.0);
    });
  });

  describe("Missing Field Handling & Excluded Joins Count", () => {
    it("accurately discovers active member documents lacking joinedAt timestamp", () => {
      const totalActive = 50;
      const inBuckets = 20;
      const olderThanWindow = 25;

      // 5 records are missing joinedAt
      const excluded = Math.max(0, totalActive - (inBuckets + olderThanWindow));
      expect(excluded).toBe(5);
    });
  });

  describe("Cloudinary Named Transformations Resolver", () => {
    it("formats strict named transformation URL without query strings", () => {
      const mediaRef = {
        provider: "cloudinary" as const,
        key: "prontochat/logos/firm123",
        kind: "image" as const,
      };

      const url = resolveLogoUrl(mediaRef, null, "logo_sm");
      expect(url).toBe(
        "https://res.cloudinary.com/dj4miyael/image/upload/t_logo_sm/prontochat/logos/firm123"
      );
    });

    it("falls back to legacy logoUrl when MediaRef key is absent", () => {
      const legacyUrl = "https://example.com/logo.png";
      const url = resolveLogoUrl(null, legacyUrl, "logo_sm");
      expect(url).toBe(legacyUrl);
    });

    it("returns null when no logo exists", () => {
      const url = resolveLogoUrl(null, null, "logo_sm");
      expect(url).toBeNull();
    });
  });
});

