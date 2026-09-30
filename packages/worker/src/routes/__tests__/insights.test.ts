import { describe, it, expect, beforeEach } from "vitest";
import type { ApiResponse, CityInsights, Station } from "@servo-map/shared";
import { createInsightsRoute } from "../insights";
import { createMemoryKV } from "../../kv/__mocks__/memory-kv";
import { KV_KEYS } from "../../kv/keys";
import type { Env } from "../../env";

const NOW = new Date("2026-09-30T06:00:00.000Z");

function station(id: string, lat: number, lng: number, price: number, updatedAt = "2026-09-30T05:00:00.000Z"): Station {
  return {
    id,
    name: id,
    brand: "Ampol",
    address: "",
    suburb: "",
    state: id.startsWith("wa") ? "wa" : "nsw",
    postcode: "",
    lat,
    lng,
    prices: [{ fuel: "U91", price, updated_at: updatedAt }],
  };
}

/** A Cache API stand-in keyed by URL, counting reads so tests can see a hit. */
function memoryCache() {
  const entries = new Map<string, Response>();
  const cache = {
    hits: 0,
    async match(request: Request) {
      const found = entries.get(request.url);
      if (found) cache.hits += 1;
      return found?.clone();
    },
    async put(request: Request, response: Response) {
      entries.set(request.url, response);
    },
  };
  return cache;
}

let env: Env;
let kvReads: string[];

beforeEach(async () => {
  const kv = createMemoryKV();
  await kv.put(KV_KEYS.stationsByState("nsw"), JSON.stringify([
    station("nsw-1", -33.87, 151.21, 230),
    station("nsw-2", -33.88, 151.2, 240),
  ]));
  await kv.put(KV_KEYS.stationsByState("wa"), JSON.stringify([station("wa-1", -31.95, 115.86, 220)]));
  kvReads = [];
  const get = kv.get.bind(kv);
  kv.get = ((key: string, type: "json") => {
    kvReads.push(key);
    return get(key, type);
  }) as KVNamespace["get"];
  env = { KV: kv, NSW_API_KEY: "", NSW_API_AUTH: "", QLD_API_TOKEN: "" };
});

describe("GET /insights/cities", () => {
  it("returns every city's figures for the fuel", async () => {
    const route = createInsightsRoute({ cache: () => undefined, now: () => NOW });
    const res = await route.request("/cities?fuel=U91", {}, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as ApiResponse<CityInsights>;
    expect(body.data.fuel).toBe("U91");
    expect(body.data.generated_at).toBe(NOW.toISOString());
    expect(body.data.cities).toHaveLength(9);
    const sydney = body.data.cities.find((c) => c.id === "sydney")!;
    expect(sydney).toMatchObject({ state: "nsw", count: 2, average: 235, min: 230, max: 240, reported_within_24h_share: 1 });
    const perth = body.data.cities.find((c) => c.id === "perth")!;
    expect(perth.average).toBe(220);
    const hobart = body.data.cities.find((c) => c.id === "hobart")!;
    expect(hobart.station_count).toBe(0);
  });

  it("reads each city state's stations once and never writes KV", async () => {
    const route = createInsightsRoute({ cache: () => undefined, now: () => NOW });
    await route.request("/cities?fuel=U91", {}, env);
    expect([...kvReads].sort()).toEqual(["stations:act", "stations:nsw", "stations:tas", "stations:wa"]);
  });

  it("serves a repeat request from the cache without reading KV", async () => {
    const cache = memoryCache();
    const route = createInsightsRoute({ cache: () => cache as unknown as Cache, now: () => NOW });
    const first = await route.request("/cities?fuel=U91", {}, env);
    expect(first.headers.get("Cache-Control")).toBe("public, max-age=300, s-maxage=900");
    kvReads = [];
    const second = await route.request("/cities?fuel=U91&junk=1", {}, env);
    expect(cache.hits).toBe(1);
    expect(kvReads).toEqual([]);
    expect(await second.json()).toEqual(await first.json());
  });

  it("caches each fuel separately", async () => {
    const cache = memoryCache();
    const route = createInsightsRoute({ cache: () => cache as unknown as Cache, now: () => NOW });
    await route.request("/cities?fuel=U91", {}, env);
    await route.request("/cities?fuel=Diesel", {}, env);
    expect(cache.hits).toBe(0);
  });

  it("rejects a missing or unknown fuel with 400 INVALID_FUEL and caches nothing", async () => {
    const cache = memoryCache();
    const route = createInsightsRoute({ cache: () => cache as unknown as Cache, now: () => NOW });
    for (const path of ["/cities", "/cities?fuel=LPG", "/cities?fuel=u91"]) {
      const res = await route.request(path, {}, env);
      expect(res.status).toBe(400);
      expect(await res.json()).toEqual({ status: "error", message: "Invalid or missing fuel type", code: "INVALID_FUEL" });
    }
    await route.request("/cities?fuel=U91", {}, env);
    expect(cache.hits).toBe(0);
  });
});
