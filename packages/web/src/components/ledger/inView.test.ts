import { describe, expect, it } from "vitest";
import type { StationWithDistance } from "@servo-map/shared";
import type { ViewBounds } from "@/components/map/viewArea";
import { CURRENT_PRICE_DAYS, cheapestInView, hasCurrentPrice, headlineScope, stationsInView } from "./inView";

const NOW = Date.parse("2026-09-30T00:00:00Z");
const HOUR = 3_600_000;

// Roughly Bankstown to the CBD: Yagoona sits outside it, to the west.
const VIEW: ViewBounds = { ne: [151.21, -33.86], sw: [151.03, -33.93] };

function station(id: string, price: number, lat: number, lng: number, hoursOld = 1): StationWithDistance {
  return {
    id,
    name: id,
    brand: "BP",
    address: "1 Test St",
    suburb: id,
    state: "nsw",
    postcode: "2000",
    lat,
    lng,
    prices: [{ fuel: "U91", price, updated_at: new Date(NOW - hoursOld * HOUR).toISOString() }],
  };
}

const INSIDE = station("inside", 209.9, -33.9, 151.1);
const CHEAPER_OUTSIDE = station("yagoona", 189.9, -33.9, 151.02);
const EDGE = station("edge", 219.9, -33.86, 151.21);

describe("stationsInView", () => {
  it("keeps stations inside the bounds, edges included, and drops the rest", () => {
    expect(stationsInView([INSIDE, CHEAPER_OUTSIDE, EDGE], VIEW).map((s) => s.id)).toEqual(["inside", "edge"]);
  });

  it("drops stations north or south of the view as well as east or west", () => {
    const north = station("north", 180, -33.5, 151.1);
    const south = station("south", 180, -34.2, 151.1);
    expect(stationsInView([north, south, INSIDE], VIEW).map((s) => s.id)).toEqual(["inside"]);
  });

  it("keeps every station until the map reports bounds", () => {
    expect(stationsInView([INSIDE, CHEAPER_OUTSIDE], null)).toHaveLength(2);
  });
});

describe("cheapestInView", () => {
  it("picks the cheapest station on screen, not a cheaper one off screen", () => {
    expect(cheapestInView([INSIDE, CHEAPER_OUTSIDE, EDGE], VIEW, "U91", NOW)?.id).toBe("inside");
  });

  it("follows the view as it moves", () => {
    const west: ViewBounds = { ne: [151.05, -33.86], sw: [150.95, -33.93] };
    expect(cheapestInView([INSIDE, CHEAPER_OUTSIDE, EDGE], west, "U91", NOW)?.id).toBe("yagoona");
  });

  it("leaves out prices older than a week, however cheap", () => {
    const outdated = station("outdated", 150, -33.9, 151.1, CURRENT_PRICE_DAYS * 24 + 1);
    expect(cheapestInView([outdated, INSIDE], VIEW, "U91", NOW)?.id).toBe("inside");
  });

  it("still quotes a price a few days old when it is the only current one", () => {
    const days = station("days", 199.9, -33.9, 151.1, 72);
    expect(cheapestInView([days], VIEW, "U91", NOW)?.id).toBe("days");
  });

  it("is null when only outdated prices are in view", () => {
    const outdated = station("outdated", 150, -33.9, 151.1, CURRENT_PRICE_DAYS * 24 + 1);
    expect(cheapestInView([outdated, CHEAPER_OUTSIDE], VIEW, "U91", NOW)).toBeNull();
  });

  it("is null when no station is in view", () => {
    expect(cheapestInView([CHEAPER_OUTSIDE], VIEW, "U91", NOW)).toBeNull();
    expect(cheapestInView([], VIEW, "U91", NOW)).toBeNull();
  });

  it("is null when nothing in view sells the fuel", () => {
    expect(cheapestInView([INSIDE], VIEW, "Diesel", NOW)).toBeNull();
  });
});

describe("hasCurrentPrice", () => {
  it("counts a price as current up to a week old", () => {
    expect(hasCurrentPrice(station("a", 200, 0, 0, CURRENT_PRICE_DAYS * 24), "U91", NOW)).toBe(true);
    expect(hasCurrentPrice(station("b", 200, 0, 0, CURRENT_PRICE_DAYS * 24 + 1), "U91", NOW)).toBe(false);
  });

  it("is false for a fuel the station does not sell", () => {
    expect(hasCurrentPrice(INSIDE, "Diesel", NOW)).toBe(false);
  });
});

describe("headlineScope", () => {
  const home = { lat: -33.9, lng: 151.1 };

  it("names the searched suburb", () => {
    expect(headlineScope("Yagoona", home, VIEW)).toBe("near Yagoona");
  });

  it("says near you while the viewer is on screen", () => {
    expect(headlineScope("", home, VIEW)).toBe("near you");
  });

  it("says in view once the map has moved away from the viewer", () => {
    expect(headlineScope("", { lat: -31.95, lng: 115.86 }, VIEW)).toBe("in view");
  });

  it("says in view before the viewer shares a location", () => {
    expect(headlineScope("", null, VIEW)).toBe("in view");
  });
});
