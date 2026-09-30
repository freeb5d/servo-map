import type { FuelType, PriceSnapshot, Station } from "@servo-map/shared";
import { haversine } from "../utils/geo";

/**
 * Which alerts to send (decision 0004). Pure functions over prices and settings; the job in
 * scripts/send-alerts.ts loads the data, applies these, and delivers through APNs.
 */

export interface Alert {
  userId: string;
  kind: "price_drop" | "cycle_low";
  /** Unique per user and kind; the job never sends the same key twice. */
  key: string;
  title: string;
  body: string;
}

/** A price drop worth a notification, in cents per litre. */
export const DROP_THRESHOLD = 3;

const fmt = (v: number) => v.toFixed(1);

/** A saved station a user wants drop alerts for, in the fuel their car takes. */
export interface Watch {
  userId: string;
  stationId: string;
  fuel: FuelType;
  tankLitres: number;
}

/**
 * Drops of `DROP_THRESHOLD`¢ or more since the job last looked. `seen` holds the last price per
 * `stationId|fuel`; a station seen for the first time sets the baseline and alerts no one.
 */
export function priceDrops(watches: Watch[], seen: Map<string, number>, stations: Map<string, Station>, day: string): Alert[] {
  const out: Alert[] = [];
  for (const w of watches) {
    const station = stations.get(w.stationId);
    const now = station?.prices.find((p) => p.fuel === w.fuel)?.price;
    const before = seen.get(`${w.stationId}|${w.fuel}`);
    if (!station || now === undefined || before === undefined) continue;
    const drop = before - now;
    if (drop < DROP_THRESHOLD) continue;
    const tank = (drop * w.tankLitres) / 100;
    out.push({
      userId: w.userId,
      kind: "price_drop",
      key: `${w.stationId}|${w.fuel}|${day}`,
      title: `${station.name} dropped ${fmt(drop)}¢`,
      body: `${w.fuel} is ${fmt(now)} now, so a full tank costs $${tank.toFixed(2)} less than before.`,
    });
  }
  return out;
}

/** A user who wants to hear when prices near home are low. */
export interface HomeWatch {
  userId: string;
  fuel: FuelType;
  home: { lat: number; lng: number };
}

/** Bottom share of the 60-day range that counts as "low". */
export const LOW_SHARE = 0.15;

/**
 * When the state average for a user's fuel sits in the bottom 15% of its last 60 days, name the
 * cheapest station within 5 km of home. One alert per user per day at most.
 */
export function cycleLows(watches: HomeWatch[], history: PriceSnapshot[], stations: Station[], day: string): Alert[] {
  const out: Alert[] = [];
  for (const w of watches) {
    const series = history.filter((s) => s.fuel === w.fuel).sort((a, b) => a.date.localeCompare(b.date)).slice(-60);
    const latest = series.at(-1);
    if (!latest || series.length < 14) continue;
    const lo = Math.min(...series.map((s) => s.avg));
    const hi = Math.max(...series.map((s) => s.avg));
    if (hi - lo < 2 || (latest.avg - lo) / (hi - lo) > LOW_SHARE) continue;
    const near = stations
      .map((s) => ({ s, price: s.prices.find((p) => p.fuel === w.fuel)?.price, km: haversine(w.home.lat, w.home.lng, s.lat, s.lng) }))
      .filter((x): x is { s: Station; price: number; km: number } => x.price !== undefined && x.km <= 5)
      .sort((a, b) => a.price - b.price)[0];
    out.push({
      userId: w.userId,
      kind: "cycle_low",
      key: `${w.fuel}|${day}`,
      title: "Prices near home are low",
      body: near
        ? `${w.fuel} is near the bottom of its cycle. ${near.s.name} is cheapest near home at ${fmt(near.price)}.`
        : `${w.fuel} averages ${fmt(latest.avg)}, near the bottom of its 60-day range.`,
    });
  }
  return out;
}

/** Hour of day in Sydney, where every user so far lives. */
export function sydneyHour(now: Date): number {
  return Number(new Intl.DateTimeFormat("en-AU", { hour: "numeric", hourCycle: "h23", timeZone: "Australia/Sydney" }).format(now));
}

/** True inside quiet hours, which may run past midnight (22 to 7). */
export function isQuiet(hour: number, start: number, end: number): boolean {
  return start > end ? hour >= start || hour < end : hour >= start && hour < end;
}

/**
 * Keeps at most one alert per user per day, never during their quiet hours, and never one they
 * have already had. Price drops win over cycle lows.
 */
export function selectDeliveries(
  alerts: Alert[],
  now: Date,
  quiet: Map<string, { start: number; end: number }>,
  sentToday: Set<string>,
  alreadySent: Set<string>,
): Alert[] {
  const hour = sydneyHour(now);
  const chosen = new Map<string, Alert>();
  for (const a of [...alerts].sort((x, y) => (x.kind === y.kind ? 0 : x.kind === "price_drop" ? -1 : 1))) {
    const q = quiet.get(a.userId) ?? { start: 22, end: 7 };
    if (isQuiet(hour, q.start, q.end)) continue;
    if (sentToday.has(a.userId) || chosen.has(a.userId)) continue;
    if (alreadySent.has(`${a.userId}|${a.kind}|${a.key}`)) continue;
    chosen.set(a.userId, a);
  }
  return [...chosen.values()];
}
