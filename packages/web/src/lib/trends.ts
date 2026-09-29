import type { FuelType, PriceSnapshot } from "@servo-map/shared";

/** UTC weekday names, indexed by Date.getUTCDay() (0 = Sunday). */
const WEEKDAY_NAMES = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
] as const;

/**
 * Snapshots for a single fuel, sorted ascending by date.
 * The backend may return multiple fuels interleaved; this narrows + orders.
 */
export function seriesForFuel(
  series: PriceSnapshot[],
  fuel: FuelType,
): PriceSnapshot[] {
  return series
    .filter((s) => s.fuel === fuel)
    .sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Cheapest UTC weekday to fill up, by averaging each day's `avg` per weekday.
 *
 * Why UTC: snapshot dates are calendar days in UTC, so we parse them as
 * `YYYY-MM-DDT00:00:00Z` to read the weekday in the same frame the data was
 * bucketed in — avoiding the local-timezone off-by-one a bare `new Date(date)`
 * would introduce. Returns null when the fuel has no snapshots.
 */
export function cheapestDayToFill(
  series: PriceSnapshot[],
  fuel: FuelType,
): { weekday: string; avg: number } | null {
  const snapshots = seriesForFuel(series, fuel);
  if (snapshots.length === 0) return null;

  const sums = new Array<number>(7).fill(0);
  const counts = new Array<number>(7).fill(0);

  for (const snap of snapshots) {
    const day = new Date(`${snap.date}T00:00:00Z`).getUTCDay();
    sums[day] += snap.avg;
    counts[day] += 1;
  }

  let bestDay = -1;
  let bestAvg = Infinity;
  for (let day = 0; day < 7; day += 1) {
    if (counts[day] === 0) continue;
    const dayAvg = sums[day] / counts[day];
    if (dayAvg < bestAvg) {
      bestAvg = dayAvg;
      bestDay = day;
    }
  }

  if (bestDay === -1) return null;
  return { weekday: WEEKDAY_NAMES[bestDay], avg: bestAvg };
}

export type CyclePosition = "low" | "mid" | "high";

/**
 * Where the latest day's average sits within the window's min..max for a fuel.
 * Bottom third = "low", top third = "high", otherwise "mid".
 *
 * Returns null with fewer than one data point. When min === max (a flat window)
 * the position is "mid" — there is no meaningful cycle to place it in, and this
 * also guards the division below against a zero span.
 */
export function cyclePosition(
  series: PriceSnapshot[],
  fuel: FuelType,
): { current: number; min: number; max: number; position: CyclePosition } | null {
  const snapshots = seriesForFuel(series, fuel);
  if (snapshots.length < 1) return null;

  const current = snapshots[snapshots.length - 1].avg;
  let min = snapshots[0].avg;
  let max = snapshots[0].avg;
  for (const snap of snapshots) {
    if (snap.avg < min) min = snap.avg;
    if (snap.avg > max) max = snap.avg;
  }

  if (min === max) {
    return { current, min, max, position: "mid" };
  }

  const ratio = (current - min) / (max - min);
  const position: CyclePosition =
    ratio <= 1 / 3 ? "low" : ratio >= 2 / 3 ? "high" : "mid";

  return { current, min, max, position };
}

// ---------------------------------------------------------------------------
// Chart and insight helpers for the /trends page and the SEO trend charts.
// ---------------------------------------------------------------------------

const DAY_MS = 86_400_000;
const SHORT_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] as const;
const MONDAY_FIRST = [1, 2, 3, 4, 5, 6, 0] as const;

/** Whole days since the Unix epoch for a `YYYY-MM-DD` date, read in UTC like the snapshots are bucketed. */
export function dayNumber(date: string): number {
  return Math.round(Date.parse(`${date}T00:00:00Z`) / DAY_MS);
}

function dateOf(day: number): string {
  return new Date(day * DAY_MS).toISOString().slice(0, 10);
}

/** "29 Sep" for `2026-09-29`. Fixed English months so server and client render identically. */
export function formatShortDate(date: string): string {
  const d = new Date(`${date}T00:00:00Z`);
  return `${d.getUTCDate()} ${SHORT_MONTHS[d.getUTCMonth()]}`;
}

const round1 = (n: number): number => Math.round(n * 10) / 10;

/** Signed one-decimal change for tables: "+4.8", "−2.4" (true minus), "0.0". */
export function formatChange(n: number): string {
  const v = round1(n);
  if (v > 0) return `+${v.toFixed(1)}`;
  if (v < 0) return `−${Math.abs(v).toFixed(1)}`;
  return "0.0";
}

/** Keeps the last `days` calendar days ending at the newest snapshot; all fuels are windowed together. */
export function windowSeries(series: PriceSnapshot[], days: number): PriceSnapshot[] {
  if (series.length === 0) return [];
  const latest = Math.max(...series.map((s) => dayNumber(s.date)));
  const cutoff = latest - (days - 1);
  return series.filter((s) => dayNumber(s.date) >= cutoff);
}

/** Calendar days from the first to the last snapshot, inclusive (missing days count). */
export function windowSpanDays(series: PriceSnapshot[], fuel: FuelType): number {
  const snaps = seriesForFuel(series, fuel);
  if (snaps.length === 0) return 0;
  return dayNumber(snaps[snaps.length - 1].date) - dayNumber(snaps[0].date) + 1;
}

/** A stretch of days with no snapshot, between two days that do have one. */
export interface DataGap {
  /** Last reported date before the gap. */
  after: string;
  /** First reported date after the gap. */
  before: string;
  /** First missing day. */
  from: string;
  /** Last missing day. */
  to: string;
  /** How many days are missing. */
  days: number;
}

/**
 * Stretches where consecutive snapshots are more than one day apart. The chart hatches
 * these and breaks the line there; the missing prices are never interpolated.
 */
export function dailyGaps(series: PriceSnapshot[], fuel: FuelType): DataGap[] {
  const snaps = seriesForFuel(series, fuel);
  const gaps: DataGap[] = [];
  for (let i = 1; i < snaps.length; i += 1) {
    const prev = dayNumber(snaps[i - 1].date);
    const next = dayNumber(snaps[i].date);
    if (next - prev > 1) {
      gaps.push({
        after: snaps[i - 1].date,
        before: snaps[i].date,
        from: dateOf(prev + 1),
        to: dateOf(next - 1),
        days: next - prev - 1,
      });
    }
  }
  return gaps;
}

/** Splits one fuel's ascending snapshots into runs of consecutive days, so a line never spans a gap. */
export function splitAtGaps(snapshots: PriceSnapshot[]): PriceSnapshot[][] {
  const runs: PriceSnapshot[][] = [];
  for (const snap of snapshots) {
    const run = runs[runs.length - 1];
    const last = run?.[run.length - 1];
    if (run && last && dayNumber(snap.date) - dayNumber(last.date) <= 1) run.push(snap);
    else runs.push([snap]);
  }
  return runs;
}

const NICE_STEPS = [1, 2, 2.5, 5, 10] as const;

/** Smallest "round" step (1, 2, 2.5, 5 × 10^k) that is at least `raw`. */
function niceStep(raw: number): number {
  const exp = Math.floor(Math.log10(raw));
  const base = 10 ** exp;
  const pick = NICE_STEPS.find((s) => s * base >= raw - 1e-9) ?? 10;
  return pick * base;
}

export interface TrendDomain {
  lo: number;
  hi: number;
  /** Round values inside the domain to draw as gridlines. */
  ticks: number[];
}

/**
 * Y domain from the daily averages, padded so the line never touches the frame. Min and max are
 * deliberately ignored: one mistyped station price would flatten the whole chart.
 */
export function trendDomain(snapshots: PriceSnapshot[], targetTicks = 5): TrendDomain {
  if (snapshots.length === 0) return { lo: 0, hi: 1, ticks: [] };
  const avgs = snapshots.map((s) => s.avg);
  const min = Math.min(...avgs);
  const max = Math.max(...avgs);
  const span = max - min || Math.max(1, max * 0.02);
  const lo = min - span * 0.12;
  const hi = max + span * 0.12;
  const step = niceStep((hi - lo) / targetTicks);
  const ticks: number[] = [];
  for (let t = Math.ceil(lo / step) * step; t <= hi + 1e-9; t += step) ticks.push(round1(t));
  return { lo, hi, ticks };
}

/**
 * Change in the daily average versus `days` earlier. Uses the nearest report within three days
 * before the target date, and null when history has a hole there (never a guess).
 */
export function changeOverDays(series: PriceSnapshot[], fuel: FuelType, days: number): number | null {
  const snaps = seriesForFuel(series, fuel);
  if (snaps.length < 2) return null;
  const latest = snaps[snaps.length - 1];
  const target = dayNumber(latest.date) - days;
  let ref: PriceSnapshot | null = null;
  for (const s of snaps) {
    const d = dayNumber(s.date);
    if (d <= target && d >= target - 3) ref = s;
  }
  return ref ? round1(latest.avg - ref.avg) : null;
}

/** The newest daily average for a fuel with its date; null with no data. */
export function latestAverage(series: PriceSnapshot[], fuel: FuelType): { date: string; avg: number } | null {
  const snaps = seriesForFuel(series, fuel);
  const last = snaps[snaps.length - 1];
  return last ? { date: last.date, avg: last.avg } : null;
}

export interface WeekdayAverage {
  weekday: string;
  /** Single-letter label for narrow charts. */
  short: string;
  /** Mean of the daily averages on that weekday; null when the window has none. */
  avg: number | null;
}

/** Mean daily average per UTC weekday, Monday first. */
export function weekdayAverages(series: PriceSnapshot[], fuel: FuelType): WeekdayAverage[] {
  const sums = new Array<number>(7).fill(0);
  const counts = new Array<number>(7).fill(0);
  for (const snap of seriesForFuel(series, fuel)) {
    const day = new Date(`${snap.date}T00:00:00Z`).getUTCDay();
    sums[day] += snap.avg;
    counts[day] += 1;
  }
  return MONDAY_FIRST.map((day) => ({
    weekday: WEEKDAY_NAMES[day],
    short: WEEKDAY_NAMES[day][0],
    avg: counts[day] > 0 ? sums[day] / counts[day] : null,
  }));
}

/** Cheapest versus dearest weekday and the gap between them; null unless two weekdays have data. */
export function weekdaySpread(
  series: PriceSnapshot[],
  fuel: FuelType,
): { cheapest: { weekday: string; avg: number }; dearest: { weekday: string; avg: number }; gap: number } | null {
  const days = weekdayAverages(series, fuel).filter(
    (d): d is WeekdayAverage & { avg: number } => d.avg !== null,
  );
  if (days.length < 2) return null;
  const sorted = [...days].sort((a, b) => a.avg - b.avg);
  const cheapest = sorted[0];
  const dearest = sorted[sorted.length - 1];
  return {
    cheapest: { weekday: cheapest.weekday, avg: cheapest.avg },
    dearest: { weekday: dearest.weekday, avg: dearest.avg },
    gap: round1(dearest.avg - cheapest.avg),
  };
}

/** Headline sentence for the cycle position; `days` is the span the high is measured over. */
export function cycleVerdict(position: CyclePosition, atWindowMax: boolean, days: number): string {
  if (position === "low") return `Near the ${days}-day low.`;
  if (position === "mid") return `Mid-range for the last ${days} days.`;
  return atWindowMax ? `At the ${days}-day high.` : `Near the ${days}-day high.`;
}

/** Dollars saved per year when each of `fillsPerMonth` monthly fills of `litres` is `centsPerLitre` cheaper. */
export function annualSaving(centsPerLitre: number, litres: number, fillsPerMonth: number): number {
  return Math.round((centsPerLitre * litres * fillsPerMonth * 12) / 100);
}
