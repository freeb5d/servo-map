import { describe, it, expect } from "vitest";
import type { Station } from "@servo-map/shared";
import { changeLine, movedIds, rankByPrice, recordVisit, replaceId, sinceLabel, type MarksById } from "@/lib/saved";

function station(id: string, prices: Record<string, number>): Station {
  return {
    id,
    name: id,
    brand: "Shell",
    address: "1 Test St",
    suburb: "Testville",
    state: "nsw",
    postcode: "2000",
    lat: -33.8,
    lng: 151.2,
    prices: Object.entries(prices).map(([fuel, price]) => ({
      fuel: fuel as Station["prices"][number]["fuel"],
      price,
      updated_at: "2026-09-29T00:00:00Z",
    })),
  };
}

// Wed 30 Sep 2026, local midday.
const NOW = new Date(2026, 8, 30, 12, 0, 0);
const at = (y: number, m: number, d: number): string => new Date(y, m, d, 9, 0, 0).toISOString();

describe("sinceLabel", () => {
  it("names today, yesterday, a weekday within the week, then a date", () => {
    expect(sinceLabel(at(2026, 8, 30), NOW)).toBe("earlier today");
    expect(sinceLabel(at(2026, 8, 29), NOW)).toBe("yesterday");
    expect(sinceLabel(at(2026, 8, 28), NOW)).toBe("Mon");
    expect(sinceLabel(at(2026, 8, 3), NOW)).toBe("3 Sep");
  });
});

describe("changeLine", () => {
  it("says a price fell, in the cheap tone", () => {
    expect(changeLine({ price: 228.9, at: at(2026, 8, 28) }, 225.9, NOW)).toEqual({
      text: "▼ 3.0 since Mon",
      tone: "cheap",
    });
  });

  it("says a price rose, in the expensive tone", () => {
    expect(changeLine({ price: 233.9, at: at(2026, 8, 28) }, 239.9, NOW)).toEqual({
      text: "▲ 6.0 since Mon",
      tone: "expensive",
    });
  });

  it("says no change when the price is the same", () => {
    expect(changeLine({ price: 225.9, at: at(2026, 8, 28) }, 225.9, NOW)).toEqual({
      text: "No change",
      tone: "none",
    });
  });

  it("does not invent a change without a previous price", () => {
    expect(changeLine(undefined, 225.9, NOW)).toEqual({ text: "Tracking from today", tone: "none" });
  });
});

describe("recordVisit", () => {
  it("marks every price on the first visit", () => {
    const next = recordVisit({}, [station("nsw-1", { U91: 225.9, E10: 223.9 })], NOW, ["nsw-1"]);
    expect(next["nsw-1"].U91?.price).toBe(225.9);
    expect(next["nsw-1"].E10?.price).toBe(223.9);
  });

  it("keeps the same object and dates when nothing changed", () => {
    const marks: MarksById = { "nsw-1": { U91: { price: 225.9, at: at(2026, 8, 28) } } };
    expect(recordVisit(marks, [station("nsw-1", { U91: 225.9 })], NOW, ["nsw-1"])).toBe(marks);
  });

  it("re-marks only the price that changed", () => {
    const old = at(2026, 8, 28);
    const marks: MarksById = {
      "nsw-1": { U91: { price: 225.9, at: old }, E10: { price: 223.9, at: old } },
    };
    const next = recordVisit(marks, [station("nsw-1", { U91: 229.9, E10: 223.9 })], NOW, ["nsw-1"]);
    expect(next["nsw-1"].U91).toEqual({ price: 229.9, at: NOW.toISOString() });
    expect(next["nsw-1"].E10?.at).toBe(old);
  });

  it("drops stations that are no longer saved but keeps ones that failed to load", () => {
    const marks: MarksById = {
      "nsw-1": { U91: { price: 225.9, at: at(2026, 8, 28) } },
      "nsw-2": { U91: { price: 230.9, at: at(2026, 8, 28) } },
    };
    const next = recordVisit(marks, [], NOW, ["nsw-1"]);
    expect(Object.keys(next)).toEqual(["nsw-1"]);
  });
});

describe("rankByPrice", () => {
  it("orders cheapest first and puts stations without the fuel last", () => {
    const items = [
      { station: station("a", { U91: 239.9 }) },
      { station: station("b", { Diesel: 250 }) },
      { station: station("c", { U91: 225.9 }) },
    ];
    expect(rankByPrice(items, "U91").map((i) => i.station.id)).toEqual(["c", "a", "b"]);
  });

  it("returns an empty list for no stations", () => {
    expect(rankByPrice([], "U91")).toEqual([]);
  });
});

describe("movedIds", () => {
  it("lists stations the API returned under a different id", () => {
    const act = { ...station("act-18711", { U91: 180 }), state: "act" as const };
    expect(movedIds([["nsw-18711", act], ["nsw-1", station("nsw-1", {})], ["nsw-2", null]])).toEqual([
      ["nsw-18711", "act-18711"],
    ]);
  });
});

describe("replaceId", () => {
  it("replaces the old id where it stood", () => {
    expect(replaceId(["a", "nsw-1", "b"], "nsw-1", "act-1")).toEqual(["a", "act-1", "b"]);
  });

  it("drops the old id when the new one is already saved", () => {
    expect(replaceId(["act-1", "nsw-1"], "nsw-1", "act-1")).toEqual(["act-1"]);
  });

  it("leaves the list alone when the old id is not saved", () => {
    expect(replaceId(["a"], "nsw-1", "act-1")).toEqual(["a"]);
  });
});
