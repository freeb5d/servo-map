import { describe, it, expect } from "vitest";
import type { FuelType, PriceSnapshot } from "@servo-map/shared";
import {
  seriesForFuel,
  cheapestDayToFill,
  cyclePosition,
  dailyGaps,
  splitAtGaps,
  trendDomain,
  changeOverDays,
  windowSeries,
  windowSpanDays,
  weekdayAverages,
  weekdaySpread,
  cycleVerdict,
  annualSaving,
  formatChange,
  formatShortDate,
  latestAverage,
} from "@/lib/trends";

/** Build a snapshot with sensible defaults; override per case. */
function snap(
  date: string,
  avg: number,
  opts: Partial<PriceSnapshot> = {},
): PriceSnapshot {
  return {
    date,
    fuel: opts.fuel ?? "U91",
    min: opts.min ?? avg - 2,
    avg,
    max: opts.max ?? avg + 2,
    station_count: opts.station_count ?? 100,
  };
}

describe("seriesForFuel", () => {
  it("filters to one fuel and sorts ascending by date", () => {
    const series: PriceSnapshot[] = [
      snap("2026-03-03", 190),
      { ...snap("2026-03-01", 250), fuel: "Diesel" as FuelType },
      snap("2026-03-01", 188),
      snap("2026-03-02", 189),
    ];
    const out = seriesForFuel(series, "U91");
    expect(out.map((s) => s.date)).toEqual([
      "2026-03-01",
      "2026-03-02",
      "2026-03-03",
    ]);
    expect(out.every((s) => s.fuel === "U91")).toBe(true);
  });

  it("returns an empty array for an empty series", () => {
    expect(seriesForFuel([], "U91")).toEqual([]);
  });

  it("returns an empty array when the fuel has no snapshots", () => {
    const series = [{ ...snap("2026-03-01", 250), fuel: "Diesel" as FuelType }];
    expect(seriesForFuel(series, "U91")).toEqual([]);
  });
});

describe("cheapestDayToFill", () => {
  it("returns the weekday with the lowest averaged daily avg", () => {
    // 2026-03-01 is a Sunday (UTC). Mon=lowest here.
    const series: PriceSnapshot[] = [
      snap("2026-03-01", 200), // Sunday
      snap("2026-03-02", 180), // Monday
      snap("2026-03-03", 195), // Tuesday
      snap("2026-03-08", 202), // Sunday
      snap("2026-03-09", 182), // Monday
    ];
    const out = cheapestDayToFill(series, "U91");
    expect(out).not.toBeNull();
    expect(out?.weekday).toBe("Monday");
    expect(out?.avg).toBeCloseTo((180 + 182) / 2, 5);
  });

  it("parses dates in UTC, not local time", () => {
    // Single Monday snapshot — must report Monday regardless of host TZ.
    const out = cheapestDayToFill([snap("2026-03-02", 180)], "U91");
    expect(out?.weekday).toBe("Monday");
  });

  it("returns null for an empty series", () => {
    expect(cheapestDayToFill([], "U91")).toBeNull();
  });

  it("returns null when the fuel has no snapshots", () => {
    const series = [{ ...snap("2026-03-01", 250), fuel: "Diesel" as FuelType }];
    expect(cheapestDayToFill(series, "U91")).toBeNull();
  });

  it("works with a single data point", () => {
    const out = cheapestDayToFill([snap("2026-03-03", 191)], "U91");
    // 2026-03-03 is a Tuesday (UTC).
    expect(out).toEqual({ weekday: "Tuesday", avg: 191 });
  });
});

describe("cyclePosition", () => {
  it("reports 'low' when latest sits in the bottom third", () => {
    const series: PriceSnapshot[] = [
      snap("2026-03-01", 180),
      snap("2026-03-02", 210),
      snap("2026-03-03", 185), // latest, near the low
    ];
    const out = cyclePosition(series, "U91");
    expect(out).toEqual({ current: 185, min: 180, max: 210, position: "low" });
  });

  it("reports 'high' when latest sits in the top third", () => {
    const series: PriceSnapshot[] = [
      snap("2026-03-01", 180),
      snap("2026-03-02", 190),
      snap("2026-03-03", 209), // latest, near the high
    ];
    const out = cyclePosition(series, "U91");
    expect(out?.position).toBe("high");
  });

  it("reports 'mid' when latest sits in the middle third", () => {
    const series: PriceSnapshot[] = [
      snap("2026-03-01", 180),
      snap("2026-03-02", 210),
      snap("2026-03-03", 195), // latest, middle
    ];
    const out = cyclePosition(series, "U91");
    expect(out?.position).toBe("mid");
  });

  it("guards against min === max (flat window) -> 'mid', no div-by-zero", () => {
    const series: PriceSnapshot[] = [
      snap("2026-03-01", 190),
      snap("2026-03-02", 190),
    ];
    const out = cyclePosition(series, "U91");
    expect(out).toEqual({ current: 190, min: 190, max: 190, position: "mid" });
  });

  it("works with a single data point (min === max === current)", () => {
    const out = cyclePosition([snap("2026-03-01", 188)], "U91");
    expect(out).toEqual({ current: 188, min: 188, max: 188, position: "mid" });
  });

  it("returns null for an empty series", () => {
    expect(cyclePosition([], "U91")).toBeNull();
  });

  it("returns null when the fuel has no snapshots", () => {
    const series = [{ ...snap("2026-03-01", 250), fuel: "Diesel" as FuelType }];
    expect(cyclePosition(series, "U91")).toBeNull();
  });
});

describe("dailyGaps", () => {
  it("returns no gaps for consecutive days", () => {
    const series = [snap("2026-03-01", 190), snap("2026-03-02", 191), snap("2026-03-03", 192)];
    expect(dailyGaps(series, "U91")).toEqual([]);
  });

  it("reports the missing days between two reported dates", () => {
    const series = [snap("2026-08-01", 197), snap("2026-09-18", 237), snap("2026-09-19", 238)];
    expect(dailyGaps(series, "U91")).toEqual([
      { after: "2026-08-01", before: "2026-09-18", from: "2026-08-02", to: "2026-09-17", days: 47 },
    ]);
  });

  it("treats a single missing day as a gap of one", () => {
    const series = [snap("2026-03-01", 190), snap("2026-03-03", 192)];
    const [gap] = dailyGaps(series, "U91");
    expect(gap).toMatchObject({ from: "2026-03-02", to: "2026-03-02", days: 1 });
  });

  it("ignores other fuels and unsorted input", () => {
    const series = [
      snap("2026-03-03", 192),
      { ...snap("2026-03-02", 250), fuel: "Diesel" as FuelType },
      snap("2026-03-01", 190),
    ];
    expect(dailyGaps(series, "U91")).toHaveLength(1);
    expect(dailyGaps(series, "Diesel")).toEqual([]);
  });

  it("finds nothing in an empty series", () => {
    expect(dailyGaps([], "U91")).toEqual([]);
  });
});

describe("splitAtGaps", () => {
  it("breaks the line where days are missing instead of joining across them", () => {
    const runs = splitAtGaps([
      snap("2026-07-30", 196),
      snap("2026-07-31", 197),
      snap("2026-09-18", 237),
      snap("2026-09-19", 238),
      snap("2026-09-21", 239),
    ]);
    expect(runs.map((r) => r.map((s) => s.date))).toEqual([
      ["2026-07-30", "2026-07-31"],
      ["2026-09-18", "2026-09-19"],
      ["2026-09-21"],
    ]);
  });

  it("returns no runs for an empty list", () => {
    expect(splitAtGaps([])).toEqual([]);
  });
});

describe("trendDomain", () => {
  it("pads the average range and returns round ticks inside it", () => {
    const d = trendDomain([snap("2026-03-01", 160), snap("2026-03-02", 240)]);
    expect(d.lo).toBeLessThan(160);
    expect(d.hi).toBeGreaterThan(240);
    expect(d.ticks.length).toBeGreaterThanOrEqual(3);
    expect(d.ticks.every((t) => t >= d.lo && t <= d.hi)).toBe(true);
    expect(d.ticks.every((t) => t % 5 === 0)).toBe(true);
  });

  it("ignores a single mistyped min or max", () => {
    const d = trendDomain([
      { ...snap("2026-03-01", 200), min: 1, max: 999 },
      snap("2026-03-02", 210),
    ]);
    expect(d.lo).toBeGreaterThan(190);
    expect(d.hi).toBeLessThan(220);
  });

  it("keeps a usable span for a flat series", () => {
    const d = trendDomain([snap("2026-03-01", 190), snap("2026-03-02", 190)]);
    expect(d.hi).toBeGreaterThan(d.lo);
  });

  it("handles no data", () => {
    expect(trendDomain([])).toEqual({ lo: 0, hi: 1, ticks: [] });
  });
});

describe("changeOverDays", () => {
  const week = [
    snap("2026-03-01", 190),
    snap("2026-03-02", 191),
    snap("2026-03-03", 192),
    snap("2026-03-04", 193),
    snap("2026-03-05", 194),
    snap("2026-03-06", 195),
    snap("2026-03-07", 196),
    snap("2026-03-08", 197),
  ];

  it("subtracts the average from exactly N days earlier", () => {
    expect(changeOverDays(week, "U91", 7)).toBe(7);
  });

  it("returns null when history has a hole at the reference date", () => {
    const holey = [snap("2026-01-01", 180), snap("2026-03-07", 196), snap("2026-03-08", 197)];
    expect(changeOverDays(holey, "U91", 7)).toBeNull();
  });

  it("uses the nearest earlier report within three days", () => {
    const series = [snap("2026-03-01", 190), snap("2026-03-08", 200)];
    expect(changeOverDays(series, "U91", 7)).toBe(10);
    expect(changeOverDays([snap("2026-02-26", 190), snap("2026-03-08", 200)], "U91", 7)).toBe(10);
  });

  it("returns null with fewer than two points", () => {
    expect(changeOverDays([snap("2026-03-01", 190)], "U91", 7)).toBeNull();
    expect(changeOverDays([], "U91", 7)).toBeNull();
  });
});

describe("windowSeries", () => {
  it("keeps the last N calendar days ending at the newest snapshot", () => {
    const series = [snap("2026-03-01", 1), snap("2026-03-05", 2), snap("2026-03-10", 3)];
    expect(windowSeries(series, 6).map((s) => s.date)).toEqual(["2026-03-05", "2026-03-10"]);
    expect(windowSeries(series, 30)).toHaveLength(3);
  });

  it("returns an empty series for empty input", () => {
    expect(windowSeries([], 30)).toEqual([]);
  });
});

describe("windowSpanDays / latestAverage", () => {
  it("counts missing days in the span", () => {
    const series = [snap("2026-03-01", 190), snap("2026-03-10", 191)];
    expect(windowSpanDays(series, "U91")).toBe(10);
    expect(windowSpanDays(series, "Diesel")).toBe(0);
  });

  it("returns the newest average with its date", () => {
    expect(latestAverage([snap("2026-03-01", 190), snap("2026-03-02", 195)], "U91")).toEqual({
      date: "2026-03-02",
      avg: 195,
    });
    expect(latestAverage([], "U91")).toBeNull();
  });
});

describe("weekdayAverages / weekdaySpread", () => {
  // 2026-03-02 Mon .. 2026-03-08 Sun
  const week = [
    snap("2026-03-02", 200),
    snap("2026-03-03", 190),
    snap("2026-03-04", 195),
    snap("2026-03-05", 205),
    snap("2026-03-06", 210),
    snap("2026-03-07", 204),
    snap("2026-03-08", 202),
  ];

  it("lists seven weekdays Monday first", () => {
    const days = weekdayAverages(week, "U91");
    expect(days.map((d) => d.short)).toEqual(["M", "T", "W", "T", "F", "S", "S"]);
    expect(days[1]).toMatchObject({ weekday: "Tuesday", avg: 190 });
  });

  it("leaves weekdays without data as null", () => {
    const days = weekdayAverages([snap("2026-03-02", 200)], "U91");
    expect(days[0].avg).toBe(200);
    expect(days.slice(1).every((d) => d.avg === null)).toBe(true);
  });

  it("reports cheapest, dearest and the gap", () => {
    const spread = weekdaySpread(week, "U91");
    expect(spread?.cheapest.weekday).toBe("Tuesday");
    expect(spread?.dearest.weekday).toBe("Friday");
    expect(spread?.gap).toBe(20);
  });

  it("agrees with cheapestDayToFill", () => {
    expect(weekdaySpread(week, "U91")?.cheapest.weekday).toBe(cheapestDayToFill(week, "U91")?.weekday);
  });

  it("needs two weekdays to compare", () => {
    expect(weekdaySpread([snap("2026-03-02", 200)], "U91")).toBeNull();
    expect(weekdaySpread([], "U91")).toBeNull();
  });
});

describe("cycleVerdict", () => {
  it("words each position", () => {
    expect(cycleVerdict("low", false, 90)).toBe("Near the 90-day low.");
    expect(cycleVerdict("mid", false, 90)).toBe("Mid-range for the last 90 days.");
    expect(cycleVerdict("high", true, 90)).toBe("At the 90-day high.");
    expect(cycleVerdict("high", false, 90)).toBe("Near the 90-day high.");
  });
});

describe("annualSaving", () => {
  it("multiplies cents per litre by litres and twelve months of fills", () => {
    // 14.4c x 50 L x 36 fills = $259.20
    expect(annualSaving(14.4, 50, 3)).toBe(259);
    expect(annualSaving(0, 50, 3)).toBe(0);
  });
});

describe("formatChange / formatShortDate", () => {
  it("signs changes and uses a true minus", () => {
    expect(formatChange(4.84)).toBe("+4.8");
    expect(formatChange(-2.4)).toBe("\u22122.4");
    expect(formatChange(0.02)).toBe("0.0");
  });

  it("formats UTC dates without locale drift", () => {
    expect(formatShortDate("2026-09-29")).toBe("29 Sep");
    expect(formatShortDate("2026-01-01")).toBe("1 Jan");
  });
});
