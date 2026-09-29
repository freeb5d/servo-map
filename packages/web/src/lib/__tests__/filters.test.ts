import { describe, expect, it } from "vitest";
import type { FuelType, StationWithDistance } from "@servo-map/shared";
import {
  DEFAULT_FILTERS,
  activeFilterCount,
  applyFilters,
  describeFilters,
  parseFilters,
  serializeFilters,
  type MapFilters,
} from "../filters";

const NOW = Date.parse("2026-09-29T12:00:00Z");
const ORIGIN = { lat: -33.8688, lng: 151.2093 };

function hoursAgo(h: number): string {
  return new Date(NOW - h * 3_600_000).toISOString();
}

function station(
  id: string,
  brand: string,
  prices: Partial<Record<FuelType, { price: number; hours?: number }>>,
  lat = ORIGIN.lat,
  lng = ORIGIN.lng,
): StationWithDistance {
  return {
    id,
    name: `${brand} ${id}`,
    brand,
    address: "1 Test St",
    suburb: "Sydney",
    state: "nsw",
    postcode: "2000",
    lat,
    lng,
    prices: Object.entries(prices).map(([fuel, v]) => ({
      fuel: fuel as FuelType,
      price: v.price,
      updated_at: hoursAgo(v.hours ?? 0),
    })),
  };
}

// About 11 km north of the origin (0.1 degrees of latitude).
const FAR_LAT = ORIGIN.lat + 0.1;
// About 3 km north of the origin.
const NEAR_LAT = ORIGIN.lat + 0.027;

const STATIONS = [
  station("metro", "Metro Petroleum", { U91: { price: 200 }, Diesel: { price: 230 } }),
  station("bp", "BP", { U91: { price: 210, hours: 3 } }, NEAR_LAT),
  station("shell", "Shell", { U91: { price: 220, hours: 8 }, E10: { price: 215 } }, FAR_LAT),
  station("costco", "Costco", { U91: { price: 190, hours: 30 } }),
  station("ind", "Some Local Servo", { U91: { price: 240 }, Diesel: { price: 250 } }),
  station("diesel-only", "Ampol", { Diesel: { price: 255 } }),
];

function ids(filters: Partial<MapFilters>, fuel: FuelType = "U91", origin: typeof ORIGIN | null = ORIGIN) {
  return applyFilters(STATIONS, { ...DEFAULT_FILTERS, ...filters }, fuel, origin, NOW).map((s) => s.id);
}

describe("parseFilters / serializeFilters", () => {
  it("parses an empty query to the defaults", () => {
    expect(parseFilters(new URLSearchParams(""))).toEqual(DEFAULT_FILTERS);
  });

  it("omits every default from the serialised form", () => {
    expect(serializeFilters(DEFAULT_FILTERS).toString()).toBe("");
    expect(serializeFilters({ ...DEFAULT_FILTERS, mode: "hide" }).toString()).toBe("");
  });

  it("round-trips a fully populated filter set", () => {
    const full: MapFilters = {
      q: "Croydon",
      sort: "distance",
      km: 5,
      max: 232.5,
      fresh: 6,
      brands: ["metro", "costco"],
      mode: "hide",
      also: ["Diesel", "E10"],
      tier: "cheap",
      group: "major",
      noMembers: true,
    };
    expect(parseFilters(serializeFilters(full))).toEqual(full);
  });

  it("round-trips through a stored query string", () => {
    const f: MapFilters = { ...DEFAULT_FILTERS, km: 10, fresh: 24, brands: ["shell"] };
    expect(parseFilters(new URLSearchParams(serializeFilters(f).toString()))).toEqual(f);
  });

  it("ignores invalid values", () => {
    const parsed = parseFilters(
      new URLSearchParams(
        "sort=sideways&km=abc&max=-4&fresh=7&brands=nope,metro,metro&mode=maybe&also=Kerosene,E10&tier=pricey&group=galaxy&nomembers=yes",
      ),
    );
    expect(parsed).toEqual({ ...DEFAULT_FILTERS, brands: ["metro"], also: ["E10"] });
  });

  it("ignores zero and blank numeric values", () => {
    const parsed = parseFilters(new URLSearchParams("km=0&max="));
    expect(parsed.km).toBeUndefined();
    expect(parsed.max).toBeUndefined();
  });

  it("trims the search query", () => {
    expect(parseFilters(new URLSearchParams("q=%20Newtown%20")).q).toBe("Newtown");
  });
});

describe("activeFilterCount", () => {
  it("counts nothing for the defaults, search and sort", () => {
    expect(activeFilterCount(DEFAULT_FILTERS)).toBe(0);
    expect(activeFilterCount({ ...DEFAULT_FILTERS, q: "x", sort: "distance" })).toBe(0);
  });

  it("counts each switched-on control once", () => {
    expect(
      activeFilterCount({
        ...DEFAULT_FILTERS,
        km: 5,
        max: 230,
        fresh: 1,
        brands: ["bp", "shell"],
        also: ["Diesel", "E10"],
        tier: "cheap",
        group: "value",
        noMembers: true,
      }),
    ).toBe(8);
  });
});

describe("applyFilters", () => {
  it("keeps every station that sells the fuel by default", () => {
    expect(ids({})).toEqual(["metro", "bp", "shell", "costco", "ind"]);
  });

  it("uses the requested fuel", () => {
    expect(ids({}, "Diesel")).toEqual(["metro", "ind", "diesel-only"]);
  });

  it("applies the price ceiling inclusively", () => {
    expect(ids({ max: 210 })).toEqual(["metro", "bp", "costco"]);
  });

  it("filters by distance from the origin", () => {
    expect(ids({ km: 5 })).toEqual(["metro", "bp", "costco", "ind"]);
    expect(ids({ km: 25 })).toHaveLength(5);
  });

  it("skips the distance filter when there is no origin", () => {
    expect(ids({ km: 1 }, "U91", null)).toHaveLength(5);
  });

  it("filters by price age", () => {
    expect(ids({ fresh: 1 })).toEqual(["metro", "ind"]);
    expect(ids({ fresh: 6 })).toEqual(["metro", "bp", "ind"]);
    expect(ids({ fresh: 24 })).toEqual(["metro", "bp", "shell", "ind"]);
  });

  it("keeps only the chosen brand families", () => {
    expect(ids({ brands: ["metro", "bp"] })).toEqual(["metro", "bp"]);
  });

  it("hides the chosen brand families", () => {
    expect(ids({ brands: ["metro", "bp"], mode: "hide" })).toEqual(["shell", "costco", "ind"]);
  });

  it("groups unknown brands under independent", () => {
    expect(ids({ brands: ["independent"] })).toEqual(["ind"]);
  });

  it("restricts to a brand group", () => {
    expect(ids({ group: "major" })).toEqual(["bp", "shell"]);
  });

  it("drops members-only brands", () => {
    expect(ids({ noMembers: true })).not.toContain("costco");
  });

  it("requires every 'also sells' fuel", () => {
    expect(ids({ also: ["Diesel"] })).toEqual(["metro", "ind"]);
    expect(ids({ also: ["Diesel", "E10"] })).toEqual([]);
  });

  it("keeps the cheapest third for the cheap tier", () => {
    expect(ids({ tier: "cheap" })).toEqual(["metro", "costco"]);
  });

  it("combines filters", () => {
    expect(ids({ km: 5, fresh: 6, max: 205, noMembers: true })).toEqual(["metro"]);
  });

  it("does not mutate its input", () => {
    const copy = [...STATIONS];
    applyFilters(STATIONS, { ...DEFAULT_FILTERS, max: 1 }, "U91", ORIGIN, NOW);
    expect(STATIONS).toEqual(copy);
  });
});

describe("describeFilters", () => {
  it("summarises active filters and is empty for the defaults", () => {
    expect(describeFilters(DEFAULT_FILTERS)).toBe("");
    expect(describeFilters({ ...DEFAULT_FILTERS, km: 5, tier: "cheap", brands: ["metro"] })).toBe(
      "≤ 5 km · Cheap · Metro",
    );
  });
});
