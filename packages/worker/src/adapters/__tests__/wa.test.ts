import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { FUEL_TYPES } from "@servo-map/shared";
import { waAdapter, parseWaFeed } from "../wa";
import type { Env } from "../../env";

const baseEnv: Env = {
  KV: undefined as unknown as KVNamespace,
  NSW_API_KEY: "",
  NSW_API_AUTH: "",
  QLD_API_TOKEN: "",
};

// 录制的 FuelWatch RSS 片段（公开 feed，无 auth）。
// Product=1 (ULP/U91) 含 2 个有坐标站点 + 1 个无坐标站点（应被丢弃）。
const ULP_RSS = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
  <title>FuelWatch Prices For All Metro Regions</title>
  <item>
    <brand>Burk</brand>
    <date>2026-06-02</date>
    <price>157.3</price>
    <trading-name>Burk Oakford</trading-name>
    <location>OAKFORD</location>
    <address>1526 Thomas Rd</address>
    <latitude>-32.20504100</latitude>
    <longitude>115.92611400</longitude>
  </item>
  <item>
    <brand>Vibe</brand>
    <date>2026-06-02</date>
    <price>158.9</price>
    <trading-name>Vibe Oakford Truckstop</trading-name>
    <location>OAKFORD</location>
    <address>1780 Thomas Rd</address>
    <latitude>-32.20930500</latitude>
    <longitude>115.95227900</longitude>
  </item>
  <item>
    <brand>Independent</brand>
    <date>2026-06-02</date>
    <price>160.0</price>
    <trading-name>No Coords Servo &amp; Co</trading-name>
    <location>NULLVILLE</location>
    <address>5 Nowhere St</address>
    <latitude></latitude>
    <longitude></longitude>
  </item>
</channel></rss>`;

// Product=4 (Diesel) 含同一个 Burk Oakford 站点 —— 用于验证多 Product 价格合并。
const DIESEL_RSS = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
  <title>FuelWatch Prices For All Metro Regions</title>
  <item>
    <brand>Burk</brand>
    <date>2026-06-02</date>
    <price>178.5</price>
    <trading-name>Burk Oakford</trading-name>
    <location>OAKFORD</location>
    <address>1526 Thomas Rd</address>
    <latitude>-32.20504100</latitude>
    <longitude>115.92611400</longitude>
  </item>
</channel></rss>`;

function fixtureFor(url: string): string {
  // 精确匹配 Product 值（注意 Product=1 不能误匹配 Product=10）。
  const product = new URL(url).searchParams.get("Product");
  if (product === "1") return ULP_RSS; // ULP / U91
  if (product === "4") return DIESEL_RSS; // Diesel
  return `<?xml version="1.0"?><rss version="2.0"><channel></channel></rss>`;
}

describe("parseWaFeed", () => {
  it("parses items and drops those without coordinates", () => {
    const items = parseWaFeed(ULP_RSS);
    expect(items.length).toBe(2);
    expect(items.map((i) => i.tradingName)).toEqual([
      "Burk Oakford",
      "Vibe Oakford Truckstop",
    ]);
  });

  it("decodes XML entities in text fields", () => {
    const xml = ULP_RSS.replace(
      "<latitude></latitude>\n    <longitude></longitude>",
      "<latitude>-31.0</latitude>\n    <longitude>116.0</longitude>",
    );
    const named = parseWaFeed(xml).find((i) => i.tradingName.includes("Servo"));
    expect(named?.tradingName).toBe("No Coords Servo & Co");
  });
});

describe("waAdapter", () => {
  beforeEach(() => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => new Response(fixtureFor(url), { status: 200 })),
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("covers only wa state", () => {
    expect(waAdapter.states).toEqual(["wa"]);
  });

  it("produces normalised Station[] with wa-<id> ids", async () => {
    const stations = await waAdapter.fetchStations(baseEnv);
    // 2 sites with coords (无坐标的被丢弃)
    expect(stations.length).toBe(2);
    expect(stations.every((s) => s.state === "wa")).toBe(true);
    expect(stations.every((s) => /^wa-[0-9a-f]+$/.test(s.id))).toBe(true);
    expect(stations.every((s) => s.lat !== 0 && s.lng !== 0)).toBe(true);
  });

  it("keeps prices in cents/L without scaling", async () => {
    const stations = await waAdapter.fetchStations(baseEnv);
    const burk = stations.find((s) => s.name === "Burk Oakford");
    const u91 = burk!.prices.find((p) => p.fuel === "U91");
    expect(u91!.price).toBe(157.3);
  });

  it("merges prices for the same station across products", async () => {
    const stations = await waAdapter.fetchStations(baseEnv);
    const burk = stations.find((s) => s.name === "Burk Oakford");
    const fuels = burk!.prices.map((p) => p.fuel).sort();
    expect(fuels).toEqual(["Diesel", "U91"]);
    expect(burk!.prices.find((p) => p.fuel === "Diesel")!.price).toBe(178.5);
  });

  it("only emits supported FuelTypes", async () => {
    const stations = await waAdapter.fetchStations(baseEnv);
    const allFuels = stations.flatMap((s) => s.prices.map((p) => p.fuel));
    expect(allFuels.every((f) => (FUEL_TYPES as readonly string[]).includes(f))).toBe(true);
  });

  it("derives a deterministic id for the same site across runs", async () => {
    const a = await waAdapter.fetchStations(baseEnv);
    const b = await waAdapter.fetchStations(baseEnv);
    const idA = a.find((s) => s.name === "Burk Oakford")!.id;
    const idB = b.find((s) => s.name === "Burk Oakford")!.id;
    expect(idA).toBe(idB);
  });

  it("title-cases the all-caps FuelWatch suburb", async () => {
    const stations = await waAdapter.fetchStations(baseEnv);
    const burk = stations.find((s) => s.name === "Burk Oakford");
    expect([burk?.address, burk?.suburb]).toEqual(["1526 Thomas Rd", "Oakford"]);
  });

  it("derives the id from the raw feed text, so recasing keeps stored ids", async () => {
    const stations = await waAdapter.fetchStations(baseEnv);
    // FNV-1a of "Burk|Burk Oakford|1526 Thomas Rd|OAKFORD", as ingested before recasing.
    expect(stations.find((s) => s.name === "Burk Oakford")?.id).toBe("wa-66cc34e9");
  });

  it("leaves postcode empty (FuelWatch feed has none)", async () => {
    const stations = await waAdapter.fetchStations(baseEnv);
    expect(stations.every((s) => s.postcode === "")).toBe(true);
  });

  it("throws when every product feed fails", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("boom", { status: 503 })),
    );
    await expect(waAdapter.fetchStations(baseEnv)).rejects.toThrow(/WA API error/);
  });
});
