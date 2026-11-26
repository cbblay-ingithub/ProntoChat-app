/**
 * Date formatting and Monday boundary calculations
 */

import { format, startOfWeek, subDays, addDays } from "date-fns";

/**
 * Returns Monday 00:00:00.000 in local admin time for a given date
 */
export function getStartOfWeekLocal(d: Date = new Date()): Date {
  // date-fns startOfWeek with weekStartsOn: 1 (Monday)
  return startOfWeek(d, { weekStartsOn: 1 });
}

/**
 * Returns formatted date e.g. "7 Mar 2026"
 */
export function formatUnambiguousDate(d: Date | string | number | null | undefined): string {
  if (!d) return "—";
  try {
    const date = typeof d === "object" && "toDate" in d ? (d as any).toDate() : new Date(d);
    return format(date, "d MMM yyyy");
  } catch {
    return "—";
  }
}

/**
 * Returns time string e.g. "14:32" or "2:32 PM"
 */
export function formatTimeLocal(d: Date | string | number | null | undefined): string {
  if (!d) return "—";
  try {
    const date = typeof d === "object" && "toDate" in d ? (d as any).toDate() : new Date(d);
    return format(date, "h:mm a");
  } catch {
    return "—";
  }
}

/**
 * Returns weekly time boundaries for Joins Over Time chart
 */
export function getWeeklyIntervals(weeks: number = 8, now: Date = new Date()): Array<{
  weekStart: Date;
  weekEnd: Date;
  label: string;
}> {
  const currentMonday = getStartOfWeekLocal(now);
  const intervals: Array<{ weekStart: Date; weekEnd: Date; label: string }> = [];

  for (let i = weeks - 1; i >= 0; i--) {
    const weekStart = subDays(currentMonday, i * 7);
    const weekEnd = addDays(weekStart, 7);
    intervals.push({
      weekStart,
      weekEnd,
      label: format(weekStart, "d MMM"),
    });
  }

  return intervals;
}

