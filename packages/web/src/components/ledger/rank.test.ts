import { describe, expect, it } from "vitest";
import type { StationWithDistance } from "@servo-map/shared";
import { cheapestStation, rankStations } from "./rank";
import { dominantState, sourceLabel } from "./stationMeta";

const NOW = Date.parse("2026-09-29T12:00:00Z");

function station(id: string, price: number, hours: number, distance: number, state: "nsw" | "qld" = "nsw"): StationWithDistance {
  return {
    id,
    name: id,
    brand: "BP",
    address: "1 Test St",
    suburb: "Sydney",
    state,
    postcode: "2000",
    lat: 0,
    lng: 0,
    distance,
    prices: [{ fuel: "U91", price, updated_at: new Date(NOW - hours * 3_600_000).toISOString() }],
  };
}

const LIST = [
  station("a", 230, 1, 1),
  station("b", 210, 2, 5),
  station("c", 190, 48, 2),
  station("d", 210, 1, 3),
];

describe("rankStations", () => {
  it("ranks by price, breaking ties by distance, and sets old prices aside", () => {
    const { fresh, old } = rankStations(LIST, "U91", "price", NOW);
    expect(fresh.map((s) => s.id)).toEqual(["d", "b", "a"]);
    expect(old.map((s) => s.id)).toEqual(["c"]);
  });

  it("ranks by distance", () => {
    const { fresh, old } = rankStations(LIST, "U91", "distance", NOW);
    expect(fresh.map((s) => s.id)).toEqual(["a", "d", "b"]);
    expect(old.map((s) => s.id)).toEqual(["c"]);
  });

  it("returns empty groups for no stations", () => {
    expect(rankStations([], "U91", "price", NOW)).toEqual({ fresh: [], old: [] });
  });
});

describe("cheapestStation", () => {
  it("prefers a current price over a cheaper old one", () => {
    expect(cheapestStation(LIST, "U91", NOW)?.id).toBe("b");
  });

  it("falls back to an old price when nothing is current", () => {
    expect(cheapestStation([LIST[2]], "U91", NOW)?.id).toBe("c");
  });

  it("is null when nobody sells the fuel", () => {
    expect(cheapestStation(LIST, "Diesel", NOW)).toBeNull();
  });
});

describe("station meta", () => {
  it("finds the dominant state", () => {
    expect(dominantState([station("a", 1, 1, 1, "qld"), station("b", 1, 1, 1), station("c", 1, 1, 1, "qld")])).toBe("qld");
    expect(dominantState([])).toBeNull();
  });

  it("names the price source", () => {
    expect(sourceLabel("nsw")).toBe("NSW FuelCheck");
    expect(sourceLabel("vic")).toBe("state feed");
  });
});
