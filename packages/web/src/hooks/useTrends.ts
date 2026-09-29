"use client";

import { useEffect, useState } from "react";
import type { AustralianState, FuelType, PriceSnapshot } from "@servo-map/shared";
import { getTrends } from "@/lib/api";
import { cyclePosition, seriesForFuel } from "@/lib/trends";

type CycleReading = NonNullable<ReturnType<typeof cyclePosition>>;

export interface TrendCycle extends CycleReading {
  /** Days of history behind min and max. */
  days: number;
}

// History changes once a day, so one fetch per state and fuel is kept for the session.
const cache = new Map<string, PriceSnapshot[]>();

function cycleFor(series: PriceSnapshot[], fuel: FuelType): TrendCycle | null {
  const days = seriesForFuel(series, fuel).length;
  const reading = cyclePosition(series, fuel);
  // A single day says nothing about a cycle.
  return reading && days >= 2 ? { ...reading, days } : null;
}

/**
 * Where the state's average price sits in its recent cycle. Null while loading or when the
 * history is unavailable, so callers can drop the cycle row instead of showing an error.
 */
export function useTrends(state: AustralianState | null, fuel: FuelType): TrendCycle | null {
  const key = state ? `${state}:${fuel}` : null;
  const [loaded, setLoaded] = useState<{ key: string; series: PriceSnapshot[] } | null>(null);

  useEffect(() => {
    if (!key || !state || cache.has(key)) return;
    let cancelled = false;
    getTrends(state, fuel)
      .then((res) => {
        cache.set(key, res.data.series);
        if (!cancelled) setLoaded({ key, series: res.data.series });
      })
      .catch(() => {
        // The verdict works without a cycle; stay silent.
      });
    return () => {
      cancelled = true;
    };
  }, [key, state, fuel]);

  if (!key) return null;
  const series = cache.get(key) ?? (loaded?.key === key ? loaded.series : null);
  return series ? cycleFor(series, fuel) : null;
}
