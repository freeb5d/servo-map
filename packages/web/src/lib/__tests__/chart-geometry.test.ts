import { describe, expect, it } from "vitest";
import { areaPath, monthTicks, smoothPath } from "../chart-geometry";
import { dayNumber } from "../trends";

describe("smoothPath", () => {
  it("handles empty and single-point input", () => {
    expect(smoothPath([])).toBe("");
    expect(smoothPath([{ x: 1, y: 2 }])).toBe("M1,2");
  });

  it("passes through every point with one cubic per segment", () => {
    const d = smoothPath([{ x: 0, y: 10 }, { x: 10, y: 0 }, { x: 20, y: 5 }]);
    expect(d.startsWith("M0,10")).toBe(true);
    expect(d.match(/C/g)).toHaveLength(2);
    expect(d.endsWith("20,5")).toBe(true);
  });

  it("keeps a flat run flat (no overshoot)", () => {
    const d = smoothPath([{ x: 0, y: 5 }, { x: 10, y: 5 }, { x: 20, y: 5 }]);
    const ys = [...d.matchAll(/,(-?[\d.]+)/g)].map((m) => Number(m[1]));
    expect(ys.every((y) => y === 5)).toBe(true);
  });
});

describe("areaPath", () => {
  it("closes the curve to the baseline", () => {
    expect(areaPath([{ x: 0, y: 1 }, { x: 10, y: 2 }], 50)).toMatch(/L10,50 L0,50 Z$/);
    expect(areaPath([{ x: 0, y: 1 }], 50)).toBe("");
  });
});

describe("monthTicks", () => {
  it("lists month starts inside the window", () => {
    const ticks = monthTicks(dayNumber("2026-07-02"), dayNumber("2026-09-29"));
    expect(ticks.map((t) => t.label)).toEqual(["Aug", "Sep"]);
    expect(ticks[0].day).toBe(dayNumber("2026-08-01"));
  });

  it("crosses a year boundary", () => {
    expect(monthTicks(dayNumber("2026-12-15"), dayNumber("2027-02-10")).map((t) => t.label)).toEqual(["Jan", "Feb"]);
  });
});
