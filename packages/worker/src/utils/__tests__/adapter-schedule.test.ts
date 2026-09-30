import { describe, it, expect } from "vitest";
import { isAdapterDue } from "../adapter-schedule";

const NOW = new Date("2026-10-01T12:00:00.000Z");
const minutesAgo = (m: number) => new Date(NOW.getTime() - m * 60_000).toISOString();

describe("isAdapterDue", () => {
  it("is always due without a minimum interval", () => {
    const meta = { nsw: { last_updated: minutesAgo(1), station_count: 10 } };
    expect(isAdapterDue({ states: ["nsw"] }, meta, NOW)).toBe(true);
  });

  it("is due when a covered state has never been written", () => {
    expect(isAdapterDue({ states: ["tas"], minIntervalMinutes: 120 }, {}, NOW)).toBe(true);
  });

  it("waits until the interval has passed since the last update", () => {
    const adapter = { states: ["tas"] as const, minIntervalMinutes: 120 };
    expect(isAdapterDue(adapter, { tas: { last_updated: minutesAgo(119), station_count: 5 } }, NOW)).toBe(false);
    expect(isAdapterDue(adapter, { tas: { last_updated: minutesAgo(120), station_count: 5 } }, NOW)).toBe(true);
  });

  it("uses the oldest update when an adapter covers several states", () => {
    const adapter = { states: ["nsw", "act"] as const, minIntervalMinutes: 60 };
    const meta = {
      nsw: { last_updated: minutesAgo(5), station_count: 10 },
      act: { last_updated: minutesAgo(90), station_count: 3 },
    };
    expect(isAdapterDue(adapter, meta, NOW)).toBe(true);
  });

  it("treats an unparseable timestamp as never written", () => {
    const meta = { tas: { last_updated: "not a date", station_count: 5 } };
    expect(isAdapterDue({ states: ["tas"], minIntervalMinutes: 120 }, meta, NOW)).toBe(true);
  });
});
