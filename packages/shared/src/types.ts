import type { FuelType } from "./fuel";
import type { AustralianState } from "./states";

export interface FuelPrice {
  fuel: FuelType;
  /** Price in cents per litre */
  price: number;
  updated_at: string;
}

export interface Station {
  /** Format: {state}-{source_id} */
  id: string;
  name: string;
  brand: string;
  address: string;
  suburb: string;
  state: AustralianState;
  postcode: string;
  lat: number;
  lng: number;
  prices: FuelPrice[];
}

export interface StationWithDistance extends Station {
  /** Distance in km, only present when lat/lng query params provided */
  distance?: number;
}

export interface PaginationMeta {
  total: number;
  limit: number;
  offset: number;
}

export interface StateMetadata {
  last_updated: string;
  station_count: number;
}

/** Daily price roll-up for one state + fuel, captured by the ingest cron */
export interface PriceSnapshot {
  /** Calendar date in YYYY-MM-DD (UTC), one entry per day */
  date: string;
  fuel: FuelType;
  min: number;
  avg: number;
  max: number;
  /** How many stations reported this fuel on this day */
  station_count: number;
}

/** A rolling time series of daily snapshots for a single state */
export interface PriceTrend {
  state: AustralianState;
  series: PriceSnapshot[];
}

/** Counts of prices in equal-width bins: bin `i` covers [start + i * width, start + (i + 1) * width). */
export interface PriceHistogram {
  /** Lower edge of the first bin, cents per litre. */
  start: number;
  /** Width of every bin, whole cents. */
  width: number;
  counts: number[];
}

/**
 * One city's prices for one fuel, from the current station data. The "recent" figures use
 * prices reported in the last 7 days; the distribution uses every price, whatever its age.
 */
export interface CityInsight {
  id: string;
  name: string;
  state: AustralianState;
  /** Stations within this many km of the city's centre count as the city. */
  radius_km: number;
  /** Stations within the city's radius that list this fuel, whatever the price's age. */
  station_count: number;
  /** Stations whose price was reported in the last 7 days. */
  count: number;
  /** Mean, lowest and highest recent price; null when `count` is 0. */
  average: number | null;
  min: number | null;
  max: number | null;
  /** Median of every price (the distribution's middle); null when `station_count` is 0. */
  median: number | null;
  /** Share (0 to 1) of `station_count` reported in the last 24 hours; null when `station_count` is 0. */
  reported_within_24h_share: number | null;
  /** Every price, whatever its age; null when `station_count` is 0. */
  histogram: PriceHistogram | null;
}

/** City comparisons for one fuel, computed from the stations in KV at `generated_at`. */
export interface CityInsights {
  fuel: FuelType;
  generated_at: string;
  cities: CityInsight[];
}

export interface ApiResponse<T> {
  status: "success";
  data: T;
  meta?: PaginationMeta;
}

export interface ApiErrorResponse {
  status: "error";
  message: string;
  code: string;
}
