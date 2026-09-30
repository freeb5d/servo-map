import { describe, expect, it } from "vitest";
import type { StationWithDistance } from "@servo-map/shared";
import { buildStationCollection, splitCheapest } from "./mapData";

const NOW = "2026-09-30T00:00:00Z";

function station(id: string, brand: string, price: number): StationWithDistance {
  return {
    id,
    name: id,
    brand,
    address: "1 Test St",
    suburb: "Sydney",
    state: "nsw",
    postcode: "2000",
    lat: -33.8,
    lng: 151.2,
    prices: [{ fuel: "U91", price, updated_at: NOW }],
  };
}

const STATIONS = [station("a", "Shell", 199.9), station("b", "Speedway", 189.9), station("c", "Mystery Fuels", 210)];

describe("buildStationCollection", () => {
  it("tags each feature with its brand family id, unknown brands as independent", () => {
    const features = buildStationCollection(STATIONS, "U91", undefined).features;
    expect(features.map((f) => f.properties.family)).toEqual(["shell", "speedway", "independent"]);
  });
});

describe("splitCheapest", () => {
  const all = buildStationCollection(STATIONS, "U91", undefined);

  it("moves the cheapest station into its own collection", () => {
    const { rest, cheapest } = splitCheapest(all, "b");
    expect(cheapest.features.map((f) => f.properties.id)).toEqual(["b"]);
    expect(rest.features.map((f) => f.properties.id)).toEqual(["a", "c"]);
  });

  it("leaves every station clustered when none is ranked cheapest", () => {
    const { rest, cheapest } = splitCheapest(all, null);
    expect(cheapest.features).toEqual([]);
    expect(rest.features).toHaveLength(3);
  });

  it("ignores an id that is not on the map", () => {
    const { rest, cheapest } = splitCheapest(all, "gone");
    expect(cheapest.features).toEqual([]);
    expect(rest.features).toHaveLength(3);
  });
});
