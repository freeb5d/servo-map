import {
  brandFamily,
  type BrandFamily,
  type FuelType,
  type Station,
} from "@servo-map/shared";
import { getFuelPrice } from "./utils";

/** Current price summary for one brand family among a set of stations. */
export interface BrandStat {
  family: BrandFamily;
  /** Stations of this family that sell the fuel. */
  count: number;
  /** Mean price in cents, one decimal. */
  avg: number;
  min: number;
}

/** Lowest current price in one suburb. */
export interface SuburbStat {
  suburb: string;
  state: Station["state"];
  min: number;
  count: number;
}

export interface PriceSpread {
  min: number;
  max: number;
  avg: number;
  count: number;
}

export interface HistogramBin {
  from: number;
  to: number;
  count: number;
}

const round1 = (n: number): number => Math.round(n * 10) / 10;

function pricesFor(stations: readonly Station[], fuel: FuelType): { station: Station; price: number }[] {
  const out: { station: Station; price: number }[] = [];
  for (const station of stations) {
    const fp = getFuelPrice(station.prices, fuel);
    if (fp) out.push({ station, price: fp.price });
  }
  return out;
}

/** Brand families ranked cheapest average first. */
export function brandStats(stations: readonly Station[], fuel: FuelType): BrandStat[] {
  const byId = new Map<string, { family: BrandFamily; sum: number; count: number; min: number }>();
  for (const { station, price } of pricesFor(stations, fuel)) {
    const family = brandFamily(station.brand);
    const acc = byId.get(family.id) ?? { family, sum: 0, count: 0, min: Infinity };
    acc.sum += price;
    acc.count += 1;
    acc.min = Math.min(acc.min, price);
    byId.set(family.id, acc);
  }
  return [...byId.values()]
    .map(({ family, sum, count, min }) => ({ family, count, avg: round1(sum / count), min }))
    .sort((a, b) => a.avg - b.avg || b.count - a.count);
}

/** Suburbs ranked by their lowest price, cheapest first. */
export function suburbStats(stations: readonly Station[], fuel: FuelType): SuburbStat[] {
  const byKey = new Map<string, SuburbStat>();
  for (const { station, price } of pricesFor(stations, fuel)) {
    const key = `${station.state}:${station.suburb.toLowerCase()}`;
    const acc = byKey.get(key);
    if (acc) {
      acc.min = Math.min(acc.min, price);
      acc.count += 1;
    } else {
      byKey.set(key, { suburb: station.suburb, state: station.state, min: price, count: 1 });
    }
  }
  return [...byKey.values()].sort((a, b) => a.min - b.min || a.suburb.localeCompare(b.suburb));
}

/** Min / max / mean price; null when no station sells the fuel. */
export function priceSpread(stations: readonly Station[], fuel: FuelType): PriceSpread | null {
  const prices = pricesFor(stations, fuel).map((p) => p.price);
  if (prices.length === 0) return null;
  const sum = prices.reduce((a, b) => a + b, 0);
  return {
    min: Math.min(...prices),
    max: Math.max(...prices),
    avg: round1(sum / prices.length),
    count: prices.length,
  };
}

/** Equal-width bins across the price range, for the filter panel's distribution. */
export function priceHistogram(prices: readonly number[], binCount = 20): HistogramBin[] {
  if (prices.length === 0 || binCount < 1) return [];
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  const width = (max - min) / binCount || 1;
  const bins: HistogramBin[] = Array.from({ length: binCount }, (_, i) => ({
    from: round1(min + i * width),
    to: round1(min + (i + 1) * width),
    count: 0,
  }));
  for (const p of prices) {
    // The maximum lands in the last bin rather than one past it.
    const i = Math.min(binCount - 1, Math.floor((p - min) / width));
    bins[i].count += 1;
  }
  return bins;
}

/** Dollars for `litres` at `cents` per litre, to the cent. */
export function fillCost(cents: number, litres: number): number {
  return Math.round(cents * litres) / 100;
}
