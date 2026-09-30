import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { FUEL_TYPES } from "@servo-map/shared";
import { nswAdapter } from "../nsw";
import type { Env } from "../../env";
import fixture from "../__fixtures__/nsw-prices.json";

const baseEnv: Env = {
  KV: undefined as unknown as KVNamespace,
  NSW_API_KEY: "test-key",
  NSW_API_AUTH: "Basic test",
  QLD_API_TOKEN: "",
};

describe("nswAdapter", () => {
  beforeEach(() => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        if (url.includes("oauth")) {
          return new Response(
            JSON.stringify({
              access_token: "test-token",
              expires_in: "43199",
              token_type: "BearerToken",
            }),
            { status: 200 },
          );
        }
        return new Response(JSON.stringify(fixture), { status: 200 });
      }),
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("covers NSW, TAS, ACT states", () => {
    expect(nswAdapter.states).toEqual(["nsw", "tas", "act"]);
  });

  it("produces normalised Station[]", async () => {
    const stations = await nswAdapter.fetchStations(baseEnv);

    // 4 stations in fixture, one has 0,0 coords → 3 out
    expect(stations.length).toBe(3);
    expect(stations.every((s) => s.id.match(/^(nsw|tas|act)-\d+$/))).toBe(true);
    expect(stations.every((s) => s.lat !== 0 && s.lng !== 0)).toBe(true);
    expect(stations.every((s) => s.prices.length > 0)).toBe(true);
  });

  it("drops stations without lat/lng", async () => {
    const stations = await nswAdapter.fetchStations(baseEnv);
    expect(stations.find((s) => s.name === "Shell No Coords")).toBeUndefined();
  });

  it("drops unsupported fuel types (LPG)", async () => {
    const stations = await nswAdapter.fetchStations(baseEnv);
    const s1001 = stations.find((s) => s.id === "nsw-1001");
    expect(s1001).toBeDefined();
    const fuels = s1001!.prices.map((p) => p.fuel);
    expect(fuels).toContain("U91");
    expect(fuels).toContain("Diesel");
    expect(fuels.every((f) => (FUEL_TYPES as readonly string[]).includes(f))).toBe(true);
  });

  it("maps NSW state string to shared AustralianState", async () => {
    const stations = await nswAdapter.fetchStations(baseEnv);
    const tasStation = stations.find((s) => s.id === "tas-1002");
    expect(tasStation?.state).toBe("tas");
  });

  it("title-cases all-caps names, addresses and suburbs", async () => {
    const stations = await nswAdapter.fetchStations(baseEnv);
    const act = stations.find((s) => s.id === "act-1004");
    expect([act?.name, act?.address, act?.suburb, act?.brand]).toEqual([
      "EG Ampol Braddon",
      "97A Lonsdale St, Braddon ACT 2612",
      "Braddon",
      "EG Ampol",
    ]);
    // Mixed-case name and address stay as sent; the suburb parsed out of it is recased.
    const sydney = stations.find((s) => s.id === "nsw-1001");
    expect([sydney?.name, sydney?.address, sydney?.suburb]).toEqual([
      "Caltex Sydney",
      "1 Test St, SYDNEY NSW 2000",
      "Sydney",
    ]);
  });

  it("parses NSW date format to ISO 8601", async () => {
    const stations = await nswAdapter.fetchStations(baseEnv);
    const s1001 = stations.find((s) => s.id === "nsw-1001");
    const u91 = s1001!.prices.find((p) => p.fuel === "U91");
    expect(u91!.updated_at).toMatch(/^2026-03-28T01:20:38/);
  });
});
