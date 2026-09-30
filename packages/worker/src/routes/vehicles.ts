import { Hono } from "hono";
import { VEHICLES, searchVehicles, vehicleMakes, withImage, type ApiResponse, type Vehicle, type VehicleWithImage } from "@servo-map/shared";
import type { Env } from "../env";

const MAX_QUERY = 60;

/**
 * The shared car catalogue (decision 0004): public, the same for every user, bundled with the
 * Worker from `@servo-map/shared`. Each generation comes with the site path of its picture. Takes
 * the list (and the set of generations with their own render) as arguments so tests can pass their own.
 */
export function createVehiclesRoute(vehicles: readonly Vehicle[] = VEHICLES, rendered?: ReadonlySet<string>) {
  const route = new Hono<{ Bindings: Env }>();

  // GET /api/v1/vehicles?q=corolla 2020&limit=20
  route.get("/", (c) => {
    const q = (c.req.query("q") ?? "").trim();
    if (q.length > MAX_QUERY) {
      return c.json({ status: "error", message: `q must be at most ${MAX_QUERY} characters`, code: "INVALID_QUERY" }, 400);
    }
    const limit = Math.min(Math.max(parseInt(c.req.query("limit") ?? "") || 20, 1), 100);
    // The catalogue changes only with a deploy; cache it hard at the edge.
    c.header("Cache-Control", "public, max-age=3600, s-maxage=86400, stale-while-revalidate=604800");
    const data = searchVehicles(vehicles, q, limit).map((v) => withImage(v, rendered));
    return c.json({ status: "success", data } satisfies ApiResponse<VehicleWithImage[]>);
  });

  // GET /api/v1/vehicles/makes
  route.get("/makes", (c) => {
    c.header("Cache-Control", "public, max-age=3600, s-maxage=86400, stale-while-revalidate=604800");
    return c.json({ status: "success", data: vehicleMakes(vehicles) } satisfies ApiResponse<string[]>);
  });

  return route;
}

export const vehiclesRoute = createVehiclesRoute();
