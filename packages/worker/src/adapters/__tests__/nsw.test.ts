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

  it("covers NSW and ACT; TAS has its own adapter", () => {
    expect(nswAdapter.states).toEqual(["nsw", "act"]);
    expect(nswAdapter.minIntervalMinutes).toBeUndefined();
  });

  it("requests the default NSW feed without a states parameter", async () => {
    await nswAdapter.fetchStations(baseEnv);
    const urls = vi.mocked(fetch).mock.calls.map(([url]) => String(url));
    expect(urls.filter((u) => u.includes("/fuel/prices"))).toEqual([
      "https://api.onegov.nsw.gov.au/FuelPriceCheck/v2/fuel/prices",
    ]);
  });

  it("produces normalised Station[]", async () => {
    const stations = await nswAdapter.fetchStations(baseEnv);

    // 3 stations in fixture, one has 0,0 coords → 2 out
    expect(stations.length).toBe(2);
    expect(stations.every((s) => s.id.match(/^(nsw|act)-\d+$/))).toBe(true);
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

  it("files ACT stations under ACT although the feed labels them NSW", async () => {
    const stations = await nswAdapter.fetchStations(baseEnv);
    const act = stations.find((s) => s.name === "EG Ampol Braddon");
    expect([act?.id, act?.state, act?.postcode]).toEqual(["act-1004", "act", "2612"]);
    expect(stations.find((s) => s.id === "nsw-1001")?.state).toBe("nsw");
  });

  it("drops stations outside its states if the feed ever includes them", async () => {
    const withTas = {
      stations: [
        ...fixture.stations,
        { ...fixture.stations[0], code: "2001", address: "2 Test Rd, HOBART TAS 7000", state: "TAS" },
      ],
      prices: [...fixture.prices, { ...fixture.prices[0], stationcode: 2001, state: "TAS" }],
    };
    vi.mocked(fetch).mockImplementation(async (url) =>
      String(url).includes("oauth")
        ? new Response(JSON.stringify({ access_token: "t", expires_in: "43199", token_type: "BearerToken" }))
        : new Response(JSON.stringify(withTas)),
    );
    const stations = await nswAdapter.fetchStations(baseEnv);
    expect(stations.some((s) => s.state === "tas")).toBe(false);
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
