import { describe, it, expect } from "vitest";
import type { PriceSnapshot, Station } from "@servo-map/shared";
import { cycleLows, isQuiet, priceDrops, selectDeliveries, sydneyHour, type Alert } from "../rules";

const station = (id: string, price: number, lat = -33.87, lng = 151.2): Station => ({
  id, name: `Station ${id}`, brand: "BP", address: "1 St", suburb: "Bondi", state: "nsw", postcode: "2026",
  lat, lng, prices: [{ fuel: "U91", price, updated_at: "2026-09-30T00:00:00Z" }],
} as unknown as Station);

describe("priceDrops", () => {
  const watch = [{ userId: "u1", stationId: "s1", fuel: "U91" as const, tankLitres: 50 }];

  it("alerts on a drop of 3¢ or more, with the saving on a full tank", () => {
    const [a] = priceDrops(watch, new Map([["s1|U91", 241.9]]), new Map([["s1", station("s1", 235.9)]]), "2026-09-30");
    expect(a).toMatchObject({ userId: "u1", kind: "price_drop", key: "s1|U91|2026-09-30", title: "Station s1 dropped 6.0¢" });
    expect(a.body).toContain("$3.00 less");
  });

  it("stays quiet for small drops, rises, first sightings and missing stations", () => {
    expect(priceDrops(watch, new Map([["s1|U91", 237.9]]), new Map([["s1", station("s1", 235.9)]]), "d")).toEqual([]);
    expect(priceDrops(watch, new Map([["s1|U91", 230]]), new Map([["s1", station("s1", 235.9)]]), "d")).toEqual([]);
    expect(priceDrops(watch, new Map(), new Map([["s1", station("s1", 235.9)]]), "d")).toEqual([]);
    expect(priceDrops(watch, new Map([["s1|U91", 250]]), new Map(), "d")).toEqual([]);
  });
});

describe("cycleLows", () => {
  const history = (last: number): PriceSnapshot[] =>
    Array.from({ length: 30 }, (_, i) => ({ date: `2026-09-${String(i + 1).padStart(2, "0")}`, fuel: "U91", min: 200, avg: i === 29 ? last : 230 + (i % 5) * 3, max: 260, station_count: 1 })) as PriceSnapshot[];
  const watch = [{ userId: "u1", fuel: "U91" as const, home: { lat: -33.87, lng: 151.2 } }];

  it("alerts near the bottom of the range and names the cheapest station nearby", () => {
    const stations = [station("near", 225.9), station("cheaper-far", 210, -34.5, 150.5)];
    const [a] = cycleLows(watch, history(229), stations, "2026-09-30");
    expect(a.kind).toBe("cycle_low");
    expect(a.body).toContain("Station near is cheapest near home at 225.9");
  });

  it("stays quiet mid-range or with too little history", () => {
    expect(cycleLows(watch, history(238), [], "d")).toEqual([]);
    expect(cycleLows(watch, history(229).slice(-10), [], "d")).toEqual([]);
  });
});

describe("delivery rules", () => {
  const a = (userId: string, kind: Alert["kind"], key = "k"): Alert => ({ userId, kind, key, title: "t", body: "b" });
  const noon = new Date("2026-09-30T02:00:00Z"); // 12:00 in Sydney (AEST, +10)
  const night = new Date("2026-09-30T13:00:00Z"); // 23:00 in Sydney

  it("reads the Sydney hour and handles quiet hours across midnight", () => {
    expect(sydneyHour(noon)).toBe(12);
    expect(isQuiet(23, 22, 7)).toBe(true);
    expect(isQuiet(6, 22, 7)).toBe(true);
    expect(isQuiet(12, 22, 7)).toBe(false);
    expect(isQuiet(13, 12, 14)).toBe(true);
  });

  it("sends one per user, prefers price drops, and respects quiet hours and history", () => {
    const alerts = [a("u1", "cycle_low"), a("u1", "price_drop"), a("u2", "cycle_low"), a("u3", "price_drop"), a("u4", "price_drop")];
    const out = selectDeliveries(alerts, noon, new Map(), new Set(["u3"]), new Set(["u4|price_drop|k"]));
    expect(out.map((x) => [x.userId, x.kind])).toEqual([["u1", "price_drop"], ["u2", "cycle_low"]]);
    expect(selectDeliveries(alerts, night, new Map(), new Set(), new Set())).toEqual([]);
  });
});
