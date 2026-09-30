import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { qldAdapter } from "../qld";
import type { Env } from "../../env";
import sitesFixture from "../__fixtures__/qld-sites.json";
import pricesFixture from "../__fixtures__/qld-prices.json";

const baseEnv: Env = {
  KV: undefined as unknown as KVNamespace,
  NSW_API_KEY: "",
  NSW_API_AUTH: "",
  QLD_API_TOKEN: "test-token",
};

describe("qldAdapter", () => {
  beforeEach(() => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        if (url.includes("GetFullSiteDetails")) {
          return new Response(JSON.stringify(sitesFixture), { status: 200 });
        }
        if (url.includes("GetSitesPrices")) {
          return new Response(JSON.stringify(pricesFixture), { status: 200 });
        }
        return new Response("not found", { status: 404 });
      }),
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("covers only qld state", () => {
    expect(qldAdapter.states).toEqual(["qld"]);
  });

  it("produces normalised Station[]", async () => {
    const stations = await qldAdapter.fetchStations(baseEnv);
    // 3 sites in fixture, one has 0,0 coords → 2 out
    expect(stations.length).toBe(2);
    expect(stations.every((s) => s.state === "qld")).toBe(true);
    expect(stations.every((s) => s.id.startsWith("qld-"))).toBe(true);
  });

  it("title-cases all-caps names and leaves mixed-case ones alone", async () => {
    const stations = await qldAdapter.fetchStations(baseEnv);
    const s2002 = stations.find((s) => s.id === "qld-2002");
    expect([s2002?.name, s2002?.address, s2002?.suburb]).toEqual([
      "Shell Gold Coast",
      "2 Beach Rd",
      "Surfers Paradise",
    ]);
    expect(stations.find((s) => s.id === "qld-2001")?.name).toBe("7-Eleven Brisbane");
  });

  it("converts 0.1-cent units to cents/L", async () => {
    const stations = await qldAdapter.fetchStations(baseEnv);
    const s2001 = stations.find((s) => s.id === "qld-2001");
    const u91 = s2001!.prices.find((p) => p.fuel === "U91");
    expect(u91!.price).toBe(185.9); // 1859 / 10
  });

  it("drops sites without lat/lng", async () => {
    const stations = await qldAdapter.fetchStations(baseEnv);
    expect(stations.find((s) => s.id === "qld-2003")).toBeUndefined();
  });

  it("drops unsupported fuel ids", async () => {
    const stations = await qldAdapter.fetchStations(baseEnv);
    const s2001 = stations.find((s) => s.id === "qld-2001");
    // FuelId 99 is not mapped and must not appear
    expect(s2001!.prices.length).toBe(2);
  });
});
