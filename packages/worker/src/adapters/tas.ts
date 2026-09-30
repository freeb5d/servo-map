import type { Station } from "@servo-map/shared";
import type { Env } from "../env";
import type { StateAdapter } from "./types";
import { fetchFuelCheckStations } from "./nsw";

/**
 * Tasmania, served by the NSW FuelCheck API (same key) but only when asked for with
 * `?states=TAS`. Fetched every two hours: every call counts against the NSW API quota
 * (2,500 a month on the free plan), which the 15-minute NSW fetch already mostly uses.
 */
const TAS_STATES = ["tas"] as const;

export const tasAdapter: StateAdapter = {
  states: TAS_STATES,
  minIntervalMinutes: 120,

  fetchStations(env: Env): Promise<Station[]> {
    return fetchFuelCheckStations(env, TAS_STATES, "?states=TAS");
  },
};
