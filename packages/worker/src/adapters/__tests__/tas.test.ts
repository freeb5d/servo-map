import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { tasAdapter } from "../tas";
import { nswAdapter } from "../nsw";
import type { Env } from "../../env";
import tasFixture from "../__fixtures__/tas-prices.json";
import nswFixture from "../__fixtures__/nsw-prices.json";

const baseEnv: Env = {
  KV: undefined as unknown as KVNamespace,
  NSW_API_KEY: "test-key",
  NSW_API_AUTH: "Basic tas-test",
  QLD_API_TOKEN: "",
};

describe("tasAdapter", () => {
  beforeEach(() => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        if (url.includes("oauth")) {
          return new Response(
            JSON.stringify({ access_token: "test-token", expires_in: "43199", token_type: "BearerToken" }),
            { status: 200 },
          );
        }
        const body = url.includes("states=TAS") ? tasFixture : nswFixture;
        return new Response(JSON.stringify(body), { status: 200 });
      }),
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("covers TAS and fetches at most every two hours", () => {
    expect(tasAdapter.states).toEqual(["tas"]);
    expect(tasAdapter.minIntervalMinutes).toBe(120);
  });

  it("asks FuelCheck for the TAS feed and returns TAS stations", async () => {
    const stations = await tasAdapter.fetchStations(baseEnv);

    const urls = vi.mocked(fetch).mock.calls.map(([url]) => String(url));
    expect(urls.filter((u) => u.includes("/fuel/prices"))).toEqual([
      "https://api.onegov.nsw.gov.au/FuelPriceCheck/v2/fuel/prices?states=TAS",
    ]);
    expect(stations.map((s) => [s.id, s.state, s.suburb, s.postcode])).toEqual([
      ["tas-1002", "tas", "Hobart", "7000"],
      ["tas-1005", "tas", "Launceston", "7250"],
    ]);
    expect(stations[1].prices).toEqual([
      { fuel: "U98", price: 214.9, updated_at: "2026-03-28T01:00:00.000Z" },
    ]);
  });

  it("shares one access token with the NSW adapter within a run", async () => {
    const env = { ...baseEnv, NSW_API_AUTH: "Basic shared-run" };
    await Promise.all([nswAdapter.fetchStations(env), tasAdapter.fetchStations(env)]);

    const tokenCalls = vi.mocked(fetch).mock.calls.filter(([url]) => String(url).includes("oauth"));
    expect(tokenCalls).toHaveLength(1);
  });

  it("requests a new token after a failed one", async () => {
    const env = { ...baseEnv, NSW_API_AUTH: "Basic retry-after-failure" };
    vi.mocked(fetch).mockImplementationOnce(async () => new Response("denied", { status: 401 }));

    await expect(tasAdapter.fetchStations(env)).rejects.toThrow(/NSW OAuth error: 401/);
    await expect(tasAdapter.fetchStations(env)).resolves.toHaveLength(2);
  });
});
