import {
  CITIES,
  type City,
  type CityInsight,
  type FuelType,
  type PriceHistogram,
  type Station,
} from "@servo-map/shared";
import { haversine } from "./geo";

const HOUR_MS = 3_600_000;
/** A price older than this is left out of a city's average and range, as the apps leave it out of rankings. */
export const RECENT_HOURS = 7 * 24;
/** "Reported in the last day". */
export const FRESH_HOURS = 24;
/** Histogram bins are this many cents wide, widened only to keep the count under MAX_BINS. */
export const BIN_WIDTH = 2;
export const MAX_BINS = 60;

/**
 * The value at fraction `p` (0 to 1) of an ascending list, interpolating between neighbours
 * (the common "type 7" definition, as spreadsheets use). NaN for an empty list.
 */
export function percentile(sorted: readonly number[], p: number): number {
  if (sorted.length === 0) return NaN;
  const at = Math.min(Math.max(p, 0), 1) * (sorted.length - 1);
  const lo = Math.floor(at);
  const hi = Math.ceil(at);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (at - lo);
}

/**
 * Prices counted into whole-cent bins `BIN_WIDTH` wide, starting on a multiple of the width.
 * A very wide spread gets wider bins rather than more than `MAX_BINS` of them.
 */
export function histogram(prices: readonly number[]): PriceHistogram | null {
  if (prices.length === 0) return null;
  const lo = Math.min(...prices);
  const hi = Math.max(...prices);
  const width = Math.max(BIN_WIDTH, Math.ceil((hi - lo + 1) / MAX_BINS));
  const start = Math.floor(lo / width) * width;
  const counts = new Array<number>(Math.floor((hi - start) / width) + 1).fill(0);
  for (const price of prices) {
    // The epsilon keeps a price on a bin edge (240.0 in 238–240 vs 240–242) out of float error.
    const index = Math.min(Math.floor((price - start) / width + 1e-9), counts.length - 1);
    counts[index] += 1;
  }
  return { start, width, counts };
}

const round1 = (value: number) => Math.round(value * 10) / 10;
const round3 = (value: number) => Math.round(value * 1000) / 1000;

/** Hours since a price was reported; Infinity when the timestamp cannot be read, so it counts as stale. */
function ageHours(updatedAt: string, now: Date): number {
  const at = Date.parse(updatedAt);
  return Number.isNaN(at) ? Infinity : (now.getTime() - at) / HOUR_MS;
}

/** One city's figures for `fuel` from `stations` (any states; matched by distance from the centre). */
export function cityInsight(city: City, stations: readonly Station[], fuel: FuelType, now: Date): CityInsight {
  const priced = stations.flatMap((s) => {
    if (haversine(city.lat, city.lng, s.lat, s.lng) > city.radiusKm) return [];
    const price = s.prices.find((p) => p.fuel === fuel);
    return price ? [{ price: price.price, age: ageHours(price.updated_at, now) }] : [];
  });
  const all = priced.map((p) => p.price).sort((a, b) => a - b);
  const recent = priced.filter((p) => p.age <= RECENT_HOURS).map((p) => p.price);
  const fresh = priced.filter((p) => p.age <= FRESH_HOURS).length;
  return {
    id: city.id,
    name: city.name,
    state: city.state,
    radius_km: city.radiusKm,
    station_count: all.length,
    count: recent.length,
    average: recent.length ? round1(recent.reduce((sum, p) => sum + p, 0) / recent.length) : null,
    min: recent.length ? Math.min(...recent) : null,
    max: recent.length ? Math.max(...recent) : null,
    median: all.length ? round1(percentile(all, 0.5)) : null,
    reported_within_24h_share: all.length ? round3(fresh / all.length) : null,
    histogram: histogram(all),
  };
}

/** Every city's figures for `fuel`, in the order of `cities`. */
export function cityInsights(
  stations: readonly Station[],
  fuel: FuelType,
  now: Date,
  cities: readonly City[] = CITIES,
): CityInsight[] {
  return cities.map((city) => cityInsight(city, stations, fuel, now));
}
