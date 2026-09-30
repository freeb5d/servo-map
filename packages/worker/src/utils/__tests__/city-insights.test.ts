import { describe, it, expect } from "vitest";
import type { City, FuelType, Station } from "@servo-map/shared";
import { cityInsight, cityInsights, histogram, percentile, MAX_BINS } from "../city-insights";

const NOW = new Date("2026-09-30T06:00:00.000Z");
const hoursAgo = (h: number) => new Date(NOW.getTime() - h * 3_600_000).toISOString();

const SYDNEY: City = { id: "sydney", name: "Sydney", state: "nsw", lat: -33.8688, lng: 151.2093, radiusKm: 20 };
const HOBART: City = { id: "hobart", name: "Hobart", state: "tas", lat: -42.8821, lng: 147.3272, radiusKm: 20 };

let seq = 0;
function station(price: number, hours: number, at = { lat: -33.87, lng: 151.21 }, fuel: FuelType = "U91"): Station {
  seq += 1;
  return {
    id: `nsw-${seq}`,
    name: `Station ${seq}`,
    brand: "Ampol",
    address: "1 Test St",
    suburb: "Sydney",
    state: "nsw",
    postcode: "2000",
    lat: at.lat,
    lng: at.lng,
    prices: [{ fuel, price, updated_at: hoursAgo(hours) }],
  };
}

describe("percentile", () => {
  it("interpolates between neighbours", () => {
    expect(percentile([1, 2, 3, 4], 0.5)).toBe(2.5);
    expect(percentile([10, 20, 30], 0.5)).toBe(20);
    expect(percentile([10, 20, 30], 0.25)).toBe(15);
  });

  it("returns the ends at 0 and 1 and clamps outside them", () => {
    expect(percentile([3, 5, 9], 0)).toBe(3);
    expect(percentile([3, 5, 9], 1)).toBe(9);
    expect(percentile([3, 5, 9], 2)).toBe(9);
  });

  it("is NaN for no values", () => {
    expect(percentile([], 0.5)).toBeNaN();
  });
});

describe("histogram", () => {
  it("counts prices into 2¢ bins starting on an even cent", () => {
    expect(histogram([221.9, 222.0, 223.9, 224.0, 229.9])).toEqual({ start: 220, width: 2, counts: [1, 2, 1, 0, 1] });
  });

  it("puts a price on a bin edge in the upper bin", () => {
    expect(histogram([238, 240])).toEqual({ start: 238, width: 2, counts: [1, 1] });
  });

  it("widens bins instead of exceeding the bin limit", () => {
    const h = histogram([150, 450])!;
    expect(h.width).toBeGreaterThan(2);
    expect(h.counts.length).toBeLessThanOrEqual(MAX_BINS);
    expect(h.counts.reduce((a, b) => a + b, 0)).toBe(2);
    expect(h.start + h.width * h.counts.length).toBeGreaterThan(450);
  });

  it("is null without prices", () => {
    expect(histogram([])).toBeNull();
  });
});

describe("cityInsight", () => {
  it("summarises recent prices within the radius", () => {
    const stations = [station(230, 1), station(240, 30), station(250, 100)];
    const c = cityInsight(SYDNEY, stations, "U91", NOW);
    expect(c).toMatchObject({ id: "sydney", name: "Sydney", state: "nsw", station_count: 3, count: 3, average: 240, min: 230, max: 250, median: 240 });
    expect(c.reported_within_24h_share).toBeCloseTo(1 / 3, 3);
  });

  it("leaves prices older than 7 days out of the average and range but keeps them in the distribution", () => {
    const stations = [station(230, 2), station(236, 2), station(300, 24 * 8)];
    const c = cityInsight(SYDNEY, stations, "U91", NOW);
    expect(c.station_count).toBe(3);
    expect(c.count).toBe(2);
    expect(c.average).toBe(233);
    expect(c.max).toBe(236);
    expect(c.median).toBe(236);
    expect(c.histogram!.counts.reduce((a, b) => a + b, 0)).toBe(3);
  });

  it("treats an unreadable timestamp as stale", () => {
    const bad = { ...station(230, 1), prices: [{ fuel: "U91" as const, price: 230, updated_at: "yesterday" }] };
    const c = cityInsight(SYDNEY, [bad], "U91", NOW);
    expect(c.count).toBe(0);
    expect(c.reported_within_24h_share).toBe(0);
  });

  it("ignores stations outside the radius and other fuels", () => {
    const stations = [
      station(230, 1),
      station(200, 1, { lat: -34.43, lng: 150.89 }), // Wollongong, ~68 km away
      station(210, 1, undefined, "Diesel"),
    ];
    const c = cityInsight(SYDNEY, stations, "U91", NOW);
    expect(c.station_count).toBe(1);
    expect(c.min).toBe(230);
  });

  it("returns an empty city with nulls rather than zeros", () => {
    const c = cityInsight(HOBART, [station(230, 1)], "U91", NOW);
    expect(c).toEqual({
      id: "hobart",
      name: "Hobart",
      state: "tas",
      radius_km: 20,
      station_count: 0,
      count: 0,
      average: null,
      min: null,
      max: null,
      median: null,
      reported_within_24h_share: null,
      histogram: null,
    });
  });

  it("keeps a city with only stale prices in the distribution, with no recent figures", () => {
    const c = cityInsight(SYDNEY, [station(230, 24 * 10)], "U91", NOW);
    expect(c).toMatchObject({ station_count: 1, count: 0, average: null, min: null, max: null, median: 230 });
  });
});

describe("cityInsights", () => {
  it("answers every city in the order given", () => {
    const rows = cityInsights([station(230, 1)], "U91", NOW, [HOBART, SYDNEY]);
    expect(rows.map((r) => r.id)).toEqual(["hobart", "sydney"]);
  });
});
