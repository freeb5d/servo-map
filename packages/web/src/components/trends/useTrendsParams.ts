"use client";

import { useCallback } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { FUEL_TYPES, type AustralianState, type FuelType } from "@servo-map/shared";
import { useFuelPreference } from "@/hooks/useFuelPreference";

export const RANGES = [30, 90] as const;
export type Range = (typeof RANGES)[number];

const DEFAULT_RANGE: Range = 90;

interface TrendsParams {
  state: AustralianState;
  fuel: FuelType;
  range: Range;
  setState: (state: AustralianState) => void;
  setFuel: (fuel: FuelType) => void;
  setRange: (range: Range) => void;
}

/**
 * State, fuel and range live in the URL (?state=nsw&fuel=U91&range=90) so a view can be shared.
 * Missing or unknown values fall back to the first live state, the remembered fuel and 90 days.
 */
export function useTrendsParams(liveStates: readonly AustralianState[]): TrendsParams {
  const router = useRouter();
  const pathname = usePathname();
  const search = useSearchParams();
  const [savedFuel, saveFuel] = useFuelPreference();

  const stateParam = search.get("state");
  const state = liveStates.find((s) => s === stateParam) ?? liveStates[0];
  const fuelParam = search.get("fuel");
  const fuel = FUEL_TYPES.find((f) => f === fuelParam) ?? savedFuel;
  const rangeParam = Number(search.get("range"));
  const range = RANGES.find((r) => r === rangeParam) ?? DEFAULT_RANGE;

  const update = useCallback(
    (key: string, value: string) => {
      const next = new URLSearchParams(search.toString());
      next.set(key, value);
      router.replace(`${pathname}?${next.toString()}`, { scroll: false });
    },
    [router, pathname, search],
  );

  return {
    state,
    fuel,
    range,
    setState: (s) => update("state", s),
    setFuel: (f) => {
      saveFuel(f);
      update("fuel", f);
    },
    setRange: (r) => update("range", String(r)),
  };
}
