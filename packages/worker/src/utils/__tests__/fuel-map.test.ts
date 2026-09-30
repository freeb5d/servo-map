import { describe, it, expect } from "vitest";
import { WA_FUEL_PRODUCTS, mapWaFuelType } from "../fuel-map";

describe("mapWaFuelType", () => {
  // FuelWatch Product codes, checked against the live feed on 2026-09-30.
  it("maps the petrol and diesel products", () => {
    expect([1, 2, 6, 4].map(mapWaFuelType)).toEqual(["U91", "U95", "U98", "Diesel"]);
  });

  it("does not read LPG (5) as U98 or E85 (10) as E10", () => {
    expect(mapWaFuelType(5)).toBeNull();
    expect(mapWaFuelType(10)).toBeNull();
    expect(mapWaFuelType(11)).toBeNull();
  });

  it("requests only the mapped products", () => {
    expect([...WA_FUEL_PRODUCTS].sort((a, b) => a - b)).toEqual([1, 2, 4, 6]);
  });
});
