import type { FuelType, StationWithDistance } from "@servo-map/shared";
import { boundsContain, type GeoPoint, type ViewBounds } from "@/components/map/viewArea";
import { cheapestStation, priceAgeHours } from "./rank";

/**
 * How long a reported price may be quoted as cheapest. NSW stations report only on a change,
 * so a price days old is usually right; past a week the station may have stopped reporting.
 * Mirrors `Station.currentFor` in apps/ios/Sources/Model.swift.
 */
export const CURRENT_PRICE_DAYS = 7;

/** Whether the station's price for the fuel is recent enough to be named cheapest. */
export function hasCurrentPrice(station: StationWithDistance, fuel: FuelType, now: number): boolean {
  return priceAgeHours(station, fuel, now) <= CURRENT_PRICE_DAYS * 24;
}

/** Stations whose position falls inside the visible map; all of them until the map reports bounds. */
export function stationsInView(
  stations: readonly StationWithDistance[],
  bounds: ViewBounds | null,
): StationWithDistance[] {
  if (!bounds) return [...stations];
  return stations.filter((s) => boundsContain(bounds, s.lat, s.lng));
}

/**
 * The cheapest station on screen with a current price for the fuel, preferring one reported in
 * the last day as the ledger does. Null when nothing in view has a current price.
 */
export function cheapestInView(
  stations: readonly StationWithDistance[],
  bounds: ViewBounds | null,
  fuel: FuelType,
  now: number,
): StationWithDistance | null {
  const current = stationsInView(stations, bounds).filter((s) => hasCurrentPrice(s, fuel, now));
  return cheapestStation(current, fuel, now);
}

/**
 * The headline's place phrase: the searched suburb, "you" while the viewer is on screen,
 * otherwise whatever the map shows.
 */
export function headlineScope(query: string, userLocation: GeoPoint | null, bounds: ViewBounds | null): string {
  if (query) return `near ${query}`;
  if (userLocation && (!bounds || boundsContain(bounds, userLocation.lat, userLocation.lng))) return "near you";
  return "in view";
}
