import {
  BRAND_GROUP_LABELS,
  FUEL_TYPES,
  brandFamily,
  brandFamilyById,
  type BrandGroup,
  type FuelType,
  type StationWithDistance,
} from "@servo-map/shared";
import { computePriceRange, getFuelPrice, haversineKm } from "./utils";

export type SortMode = "price" | "distance";
export type BrandMode = "only" | "hide";

/** Every filter the map page can apply; the URL is its serialised form. */
export interface MapFilters {
  /** Searched suburb or postcode. Resolved by the API, so applyFilters ignores it. */
  q: string;
  sort: SortMode;
  /** Maximum distance from the origin, km. */
  km?: number;
  /** Price ceiling, cents per litre. */
  max?: number;
  /** Price must have been reported within this many hours. */
  fresh?: 1 | 6 | 24;
  /** Brand family ids. */
  brands: string[];
  mode: BrandMode;
  /** The station must also sell every fuel listed. */
  also: FuelType[];
  /** Cheapest third of the visible stations only. */
  tier?: "cheap";
  group?: BrandGroup;
  noMembers: boolean;
}

export const DEFAULT_FILTERS: MapFilters = {
  q: "",
  sort: "price",
  brands: [],
  mode: "only",
  also: [],
  noMembers: false,
};

export const FRESH_OPTIONS = [1, 6, 24] as const;
export const KM_OPTIONS = [2, 5, 10, 25] as const;

/** Query keys owned by the filters; anything else in the URL is left alone. */
export const FILTER_KEYS = [
  "q",
  "sort",
  "km",
  "max",
  "fresh",
  "brands",
  "mode",
  "also",
  "tier",
  "group",
  "nomembers",
] as const;

const GROUPS = Object.keys(BRAND_GROUP_LABELS) as BrandGroup[];

function positiveNumber(raw: string | null): number | undefined {
  if (raw === null || raw.trim() === "") return undefined;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : undefined;
}

function csv(raw: string | null): string[] {
  return raw ? raw.split(",").map((s) => s.trim()).filter(Boolean) : [];
}

/** Reads filters from a query string; unknown or malformed values fall back to defaults. */
export function parseFilters(params: URLSearchParams): MapFilters {
  const fresh = Number(params.get("fresh"));
  const group = params.get("group");
  const brands = csv(params.get("brands")).filter((id) => brandFamilyById(id) !== undefined);
  const also = csv(params.get("also")).filter((f): f is FuelType =>
    (FUEL_TYPES as readonly string[]).includes(f),
  );

  return {
    q: (params.get("q") ?? "").trim(),
    sort: params.get("sort") === "distance" ? "distance" : "price",
    km: positiveNumber(params.get("km")),
    max: positiveNumber(params.get("max")),
    fresh: (FRESH_OPTIONS as readonly number[]).includes(fresh) ? (fresh as 1 | 6 | 24) : undefined,
    brands: [...new Set(brands)],
    mode: params.get("mode") === "hide" ? "hide" : "only",
    also: [...new Set(also)],
    tier: params.get("tier") === "cheap" ? "cheap" : undefined,
    group: GROUPS.find((g) => g === group),
    noMembers: params.get("nomembers") === "1",
  };
}

/** Writes filters as a query string, leaving out every value that equals its default. */
export function serializeFilters(filters: MapFilters): URLSearchParams {
  const p = new URLSearchParams();
  if (filters.q) p.set("q", filters.q);
  if (filters.sort !== DEFAULT_FILTERS.sort) p.set("sort", filters.sort);
  if (filters.km !== undefined) p.set("km", String(filters.km));
  if (filters.max !== undefined) p.set("max", String(filters.max));
  if (filters.fresh !== undefined) p.set("fresh", String(filters.fresh));
  if (filters.brands.length > 0) {
    p.set("brands", filters.brands.join(","));
    // The mode only means something while brands are picked.
    if (filters.mode !== DEFAULT_FILTERS.mode) p.set("mode", filters.mode);
  }
  if (filters.also.length > 0) p.set("also", filters.also.join(","));
  if (filters.tier) p.set("tier", filters.tier);
  if (filters.group) p.set("group", filters.group);
  if (filters.noMembers) p.set("nomembers", "1");
  return p;
}

/** How many filter controls are switched on. Search and sort are not filters. */
export function activeFilterCount(filters: MapFilters): number {
  let n = 0;
  if (filters.km !== undefined) n += 1;
  if (filters.max !== undefined) n += 1;
  if (filters.fresh !== undefined) n += 1;
  if (filters.brands.length > 0) n += 1;
  if (filters.also.length > 0) n += 1;
  if (filters.tier) n += 1;
  if (filters.group) n += 1;
  if (filters.noMembers) n += 1;
  return n;
}

/** Short human summary of the active filters, used to name saved presets. */
export function describeFilters(filters: MapFilters): string {
  const parts: string[] = [];
  if (filters.km !== undefined) parts.push(`≤ ${filters.km} km`);
  if (filters.max !== undefined) parts.push(`≤ ${filters.max.toFixed(1)}`);
  if (filters.tier) parts.push("Cheap");
  if (filters.fresh !== undefined) parts.push(`< ${filters.fresh} h`);
  if (filters.group) parts.push(BRAND_GROUP_LABELS[filters.group]);
  if (filters.brands.length > 0) {
    const names = filters.brands.map((id) => brandFamilyById(id)?.name ?? id);
    const shown = names.length > 2 ? `${names.slice(0, 2).join(", ")} +${names.length - 2}` : names.join(", ");
    parts.push(filters.mode === "hide" ? `Hide ${shown}` : shown);
  }
  if (filters.also.length > 0) parts.push(`+ ${filters.also.join(" ")}`);
  if (filters.noMembers) parts.push("No members-only");
  return parts.join(" · ");
}

interface Origin {
  lat: number;
  lng: number;
}

/**
 * Applies every filter to already-loaded stations. Stations that do not sell the
 * selected fuel are dropped: the page ranks by that fuel, so they have no place in it.
 * The cheap tier is the bottom third of the input set, so it stays put as other
 * filters narrow the list.
 */
export function applyFilters(
  stations: readonly StationWithDistance[],
  filters: MapFilters,
  fuel: FuelType,
  origin: Origin | null,
  now: number = Date.now(),
): StationWithDistance[] {
  const priced = stations.filter((s) => getFuelPrice(s.prices, fuel) !== undefined);
  const cheapBelow =
    filters.tier === "cheap"
      ? computePriceRange(priced.map((s) => getFuelPrice(s.prices, fuel)!.price)).cheapBelow
      : 0;
  const brandSet = new Set(filters.brands);

  return priced.filter((station) => {
    const fp = getFuelPrice(station.prices, fuel)!;
    if (filters.max !== undefined && fp.price > filters.max) return false;
    if (filters.tier && fp.price > cheapBelow) return false;
    if (filters.fresh !== undefined) {
      const ageHours = (now - new Date(fp.updated_at).getTime()) / 3_600_000;
      if (ageHours > filters.fresh) return false;
    }
    if (filters.km !== undefined && origin) {
      if (haversineKm(origin.lat, origin.lng, station.lat, station.lng) > filters.km) return false;
    }
    const family = brandFamily(station.brand);
    if (brandSet.size > 0 && brandSet.has(family.id) !== (filters.mode === "only")) return false;
    if (filters.group && family.group !== filters.group) return false;
    if (filters.noMembers && family.group === "members") return false;
    return filters.also.every((f) => getFuelPrice(station.prices, f) !== undefined);
  });
}
