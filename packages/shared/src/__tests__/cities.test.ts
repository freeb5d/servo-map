import { describe, expect, it } from "vitest";
import { CITIES } from "../cities";
import { AUSTRALIAN_STATES } from "../states";

// Great-circle distance in km; kept here so the shared package stays free of runtime helpers.
function km(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const h =
    Math.sin(rad(b.lat - a.lat) / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(rad(b.lng - a.lng) / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

describe("CITIES", () => {
  it("lists the nine cities the Trends tab compares", () => {
    expect(CITIES.map((c) => c.name)).toEqual([
      "Sydney",
      "Newcastle",
      "Wollongong",
      "Central Coast",
      "Canberra",
      "Perth",
      "Bunbury",
      "Hobart",
      "Launceston",
    ]);
  });

  it("gives every city a unique kebab-case id, a real state and a positive radius", () => {
    expect(new Set(CITIES.map((c) => c.id)).size).toBe(CITIES.length);
    for (const c of CITIES) {
      expect(c.id).toMatch(/^[a-z]+(-[a-z]+)*$/);
      expect(AUSTRALIAN_STATES).toContain(c.state);
      expect(c.radiusKm).toBeGreaterThan(0);
    }
  });

  it("places every centre in Australia", () => {
    for (const c of CITIES) {
      expect(c.lat).toBeGreaterThan(-44);
      expect(c.lat).toBeLessThan(-10);
      expect(c.lng).toBeGreaterThan(112);
      expect(c.lng).toBeLessThan(154);
    }
  });

  it("never lets two cities share a station", () => {
    for (const [i, a] of CITIES.entries()) {
      for (const b of CITIES.slice(i + 1)) {
        expect(km(a, b), `${a.name} and ${b.name}`).toBeGreaterThan(a.radiusKm + b.radiusKm);
      }
    }
  });
});
