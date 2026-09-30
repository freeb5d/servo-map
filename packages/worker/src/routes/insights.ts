import { Hono } from "hono";
import {
  CITIES,
  FUEL_TYPES,
  type ApiResponse,
  type City,
  type CityInsights,
  type FuelType,
} from "@servo-map/shared";
import type { Env } from "../env";
import { readStationsByState } from "../kv/read";
import { cityInsights } from "../utils/city-insights";

/** Clients may keep an answer 5 minutes; the edge (and the Cache API copy) keeps it 15, one ingest cycle. */
const CACHE_CONTROL = "public, max-age=300, s-maxage=900";

export interface InsightsRouteOptions {
  /** The Cache API store; absent in tests and under runtimes without `caches`. */
  cache?: () => Cache | undefined;
  now?: () => Date;
  cities?: readonly City[];
}

const workerCache = () => (typeof caches === "undefined" ? undefined : caches.default);

/**
 * Comparisons computed from the current station data in KV (decision 0008). Read-only; the
 * aggregation runs at most once per fuel per 15 minutes per edge location, via the Cache API.
 */
export function createInsightsRoute(options: InsightsRouteOptions = {}) {
  const { cache = workerCache, now = () => new Date(), cities = CITIES } = options;
  const route = new Hono<{ Bindings: Env }>();

  // GET /api/v1/insights/cities?fuel=U91
  route.get("/cities", async (c) => {
    const fuel = c.req.query("fuel") as FuelType | undefined;
    if (!fuel || !FUEL_TYPES.includes(fuel)) {
      return c.json({ status: "error", message: "Invalid or missing fuel type", code: "INVALID_FUEL" }, 400);
    }

    // One key per fuel, whatever else the query carries, so stray parameters cannot bypass the cache.
    const store = cache();
    const key = new Request(`${new URL(c.req.url).origin}/api/v1/insights/cities?fuel=${fuel}`);
    const hit = await store?.match(key);
    if (hit) return hit;

    const states = [...new Set(cities.map((city) => city.state))];
    const stations = (await Promise.all(states.map((s) => readStationsByState(c.env.KV, s)))).flat();
    const at = now();
    const data: CityInsights = { fuel, generated_at: at.toISOString(), cities: cityInsights(stations, fuel, at, cities) };

    c.header("Cache-Control", CACHE_CONTROL);
    const response = c.json({ status: "success", data } satisfies ApiResponse<CityInsights>);
    if (store) {
      const put = store.put(key, response.clone());
      try {
        c.executionCtx.waitUntil(put);
      } catch {
        // No execution context (tests, local tools): finish the write before answering.
        await put;
      }
    }
    return response;
  });

  return route;
}

export const insightsRoute = createInsightsRoute();
