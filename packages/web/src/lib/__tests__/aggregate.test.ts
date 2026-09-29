import { describe, expect, it } from "vitest";
import type { FuelType, Station } from "@servo-map/shared";
import { brandStats, fillCost, priceHistogram, priceSpread, suburbStats } from "../aggregate";

function station(id: string, brand: string, suburb: string, prices: Partial<Record<FuelType, number>>): Station {
  return {
    id,
    name: `${brand} ${suburb}`,
    brand,
    address: "1 Test St",
    suburb,
    state: "nsw",
    postcode: "2000",
    lat: -33.8,
    lng: 151.2,
    prices: Object.entries(prices).map(([fuel, price]) => ({
      fuel: fuel as FuelType,
      price: price as number,
      updated_at: "2026-09-29T00:00:00Z",
    })),
  };
}

const STATIONS = [
  station("a", "Metro Fuel", "Croydon", { U91: 225.9, Diesel: 244.9 }),
  station("b", "Metro Petroleum", "Croydon", { U91: 227.9 }),
  station("c", "EG Ampol", "Ashfield", { U91: 238.6 }),
  station("d", "Ampol Foodary", "Enfield", { U91: 240.2 }),
  station("e", "BP", "Enfield", { Diesel: 250.1 }),
];

describe("brandStats", () => {
  it("groups raw names into families and ranks by average", () => {
    const stats = brandStats(STATIONS, "U91");
    expect(stats.map((s) => [s.family.id, s.count, s.avg, s.min])).toEqual([
      ["metro", 2, 226.9, 225.9],
      ["ampol", 2, 239.4, 238.6],
    ]);
  });

  it("skips stations without the fuel", () => {
    expect(brandStats(STATIONS, "Diesel").map((s) => s.family.id)).toEqual(["metro", "bp"]);
    expect(brandStats(STATIONS, "U98")).toEqual([]);
  });
});

describe("suburbStats", () => {
  it("keeps the lowest price per suburb, cheapest first", () => {
    expect(suburbStats(STATIONS, "U91").map((s) => [s.suburb, s.min, s.count])).toEqual([
      ["Croydon", 225.9, 2],
      ["Ashfield", 238.6, 1],
      ["Enfield", 240.2, 1],
    ]);
  });
});

describe("priceSpread", () => {
  it("returns min, max and mean", () => {
    expect(priceSpread(STATIONS, "U91")).toEqual({ min: 225.9, max: 240.2, avg: 233.2, count: 4 });
  });

  it("returns null when nothing sells the fuel", () => {
    expect(priceSpread(STATIONS, "E10")).toBeNull();
  });
});

describe("priceHistogram", () => {
  it("puts every price in exactly one bin, including the maximum", () => {
    const bins = priceHistogram([200, 210, 220, 230, 240], 4);
    expect(bins).toHaveLength(4);
    expect(bins.reduce((n, b) => n + b.count, 0)).toBe(5);
    expect(bins[3].count).toBe(2);
  });

  it("handles a flat or empty input", () => {
    expect(priceHistogram([225.9, 225.9], 3).map((b) => b.count)).toEqual([2, 0, 0]);
    expect(priceHistogram([], 5)).toEqual([]);
  });
});

describe("fillCost", () => {
  it("prices a fill in dollars", () => {
    expect(fillCost(225.9, 50)).toBe(112.95);
    expect(fillCost(171.9, 42.3)).toBe(72.71);
  });
});
