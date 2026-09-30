import type { FuelType, Station } from "@servo-map/shared";
import { getFuelPrice } from "./utils";

/** The price seen on a previous visit and when it was first seen. */
export interface PriceMark {
  price: number;
  /** ISO time of the visit that first saw this price. */
  at: string;
}

export type PriceMarks = Partial<Record<FuelType, PriceMark>>;

/** Last-seen prices per saved station id, kept on this device. */
export type MarksById = Record<string, PriceMarks>;

export type ChangeTone = "cheap" | "expensive" | "none";

export interface ChangeLine {
  text: string;
  tone: ChangeTone;
}

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] as const;
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] as const;

const startOfDay = (d: Date): number => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();

/** Human label for when a price was first seen: "earlier today", "yesterday", "Mon", or "3 Sep". */
export function sinceLabel(atIso: string, now: Date): string {
  const at = new Date(atIso);
  const days = Math.round((startOfDay(now) - startOfDay(at)) / 86_400_000);
  if (days <= 0) return "earlier today";
  if (days === 1) return "yesterday";
  if (days < 7) return WEEKDAYS[at.getDay()];
  return `${at.getDate()} ${MONTHS[at.getMonth()]}`;
}

/** The line under a saved station: how its price moved since the last visit that saw a different price. */
export function changeLine(mark: PriceMark | undefined, current: number, now: Date): ChangeLine {
  if (!mark) return { text: "Tracking from today", tone: "none" };
  const diff = Math.round((current - mark.price) * 10) / 10;
  if (diff === 0) return { text: "No change", tone: "none" };
  const since = sinceLabel(mark.at, now);
  return diff < 0
    ? { text: `▼ ${Math.abs(diff).toFixed(1)} since ${since}`, tone: "cheap" }
    : { text: `▲ ${diff.toFixed(1)} since ${since}`, tone: "expensive" };
}

/**
 * Marks after a visit: a price is re-marked only when it differs from the stored one, so the
 * "since" date stays anchored to the last real change. Ids outside `keep` (unsaved stations) are
 * dropped. Returns the same object when nothing changed, so callers can skip a write.
 */
export function recordVisit(
  marks: MarksById,
  stations: readonly Station[],
  now: Date,
  keep: readonly string[],
): MarksById {
  const keepSet = new Set(keep);
  const next: MarksById = {};
  let changed = false;

  for (const id of Object.keys(marks)) {
    if (keepSet.has(id)) next[id] = marks[id];
    else changed = true;
  }

  for (const station of stations) {
    const current: PriceMarks = { ...next[station.id] };
    let touched = false;
    for (const fp of station.prices) {
      if (current[fp.fuel]?.price !== fp.price) {
        current[fp.fuel] = { price: fp.price, at: now.toISOString() };
        touched = true;
      }
    }
    if (touched) {
      next[station.id] = current;
      changed = true;
    }
  }
  return changed ? next : marks;
}

/** Stations cheapest first for a fuel; ones that do not sell it go last in their original order. */
export function rankByPrice<T extends { station: Station }>(items: readonly T[], fuel: FuelType): T[] {
  const priced = (item: T): number => getFuelPrice(item.station.prices, fuel)?.price ?? Infinity;
  return [...items].sort((a, b) => priced(a) - priced(b));
}

/**
 * Saved ids to replace: the API answers a retired id with the station under its current id
 * (ACT stations moved from "nsw-<code>" to "act-<code>"), and the saved list should follow.
 */
export function movedIds(loaded: readonly (readonly [string, Station | null])[]): [string, string][] {
  return loaded.flatMap(([requested, station]) =>
    station && station.id !== requested ? [[requested, station.id] as [string, string]] : [],
  );
}

/** Replaces `from` with `to` in place, dropping `from` when `to` is already saved. */
export function replaceId(ids: readonly string[], from: string, to: string): string[] {
  if (!ids.includes(from)) return [...ids];
  return ids.includes(to) ? ids.filter((id) => id !== from) : ids.map((id) => (id === from ? to : id));
}
