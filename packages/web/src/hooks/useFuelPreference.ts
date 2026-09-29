"use client";

import type { FuelType } from "@servo-map/shared";
import { useLocalStorage } from "./useLocalStorage";

/** The viewer's fuel, remembered across pages and visits. */
export function useFuelPreference(): [FuelType, (fuel: FuelType) => void] {
  return useLocalStorage<FuelType>("servo-map:fuel", "U91");
}
