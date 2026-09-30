import type { FuelType, StationWithDistance } from "@servo-map/shared";
import type { SortMode } from "@/lib/filters";
import { getFuelPrice } from "@/lib/utils";

/** Prices reported longer ago than this are shown unranked below a separator. */
export const OLD_PRICE_HOURS = 24;

export interface RankedStations {
  /** Ranked stations, in the requested sort order. */
  fresh: StationWithDistance[];
  /** Stations whose price is older than OLD_PRICE_HOURS, in the same order. */
  old: StationWithDistance[];
}

function priceOf(station: StationWithDistance, fuel: FuelType): number {
  return getFuelPrice(station.prices, fuel)?.price ?? Infinity;
}

/** Hours since the station last reported the fuel; Infinity when it does not sell it. */
export function priceAgeHours(station: StationWithDistance, fuel: FuelType, now: number): number {
  const fp = getFuelPrice(station.prices, fuel);
  return fp ? (now - new Date(fp.updated_at).getTime()) / 3_600_000 : Infinity;
}

/** Sorts stations and moves the ones with old prices out of the ranking. */
export function rankStations(
  stations: readonly StationWithDistance[],
  fuel: FuelType,
  sort: SortMode,
  now: number,
): RankedStations {
  const byPrice = (a: StationWithDistance, b: StationWithDistance) =>
    priceOf(a, fuel) - priceOf(b, fuel) || (a.distance ?? Infinity) - (b.distance ?? Infinity);
  const byDistance = (a: StationWithDistance, b: StationWithDistance) =>
    (a.distance ?? Infinity) - (b.distance ?? Infinity) || priceOf(a, fuel) - priceOf(b, fuel);

  const sorted = [...stations].sort(sort === "price" ? byPrice : byDistance);
  const fresh: StationWithDistance[] = [];
  const old: StationWithDistance[] = [];
  for (const station of sorted) {
    (priceAgeHours(station, fuel, now) > OLD_PRICE_HOURS ? old : fresh).push(station);
  }
  return { fresh, old };
}

/**
 * The cheapest station with a current price, falling back to any priced one. Equal prices go to
 * the nearer station, as in rankStations, so the verdict names the ledger's first row.
 */
export function cheapestStation(
  stations: readonly StationWithDistance[],
  fuel: FuelType,
  now: number,
): StationWithDistance | null {
  let best: StationWithDistance | null = null;
  let bestIsFresh = false;
  for (const station of stations) {
    const price = priceOf(station, fuel);
    if (!Number.isFinite(price)) continue;
    const isFresh = priceAgeHours(station, fuel, now) <= OLD_PRICE_HOURS;
    const bestPrice = best === null ? Infinity : priceOf(best, fuel);
    const better =
      best === null ||
      (isFresh && !bestIsFresh) ||
      (isFresh === bestIsFresh &&
        (price < bestPrice ||
          (price === bestPrice && (station.distance ?? Infinity) < (best.distance ?? Infinity))));
    if (better) {
      best = station;
      bestIsFresh = isFresh;
    }
  }
  return best;
}

/**
 * The id of the station the map tags "Cheapest" and the ledger tints: the cheapest one with a
 * current price. Null when only old prices remain, since those are not ranked.
 */
export function cheapestRankedId(
  stations: readonly StationWithDistance[],
  fuel: FuelType,
  now: number,
): string | null {
  const best = cheapestStation(stations, fuel, now);
  return best && priceAgeHours(best, fuel, now) <= OLD_PRICE_HOURS ? best.id : null;
}
