import type {
  Station,
  StationWithDistance,
  ApiResponse,
  PaginationMeta,
  StateMetadata,
  AustralianState,
  PriceTrend,
  FuelType,
} from "@servo-map/shared";
import { normalizeStation } from "./place-names";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8787";

async function fetchApi<T>(path: string): Promise<ApiResponse<T>> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) {
    throw new Error(`API error: ${res.status} ${res.statusText}`);
  }
  return res.json();
}

export async function getStations(params?: {
  state?: string;
  suburb?: string;
  brand?: string;
  fuel?: string;
  lat?: number;
  lng?: number;
  radius?: number;
  sort?: "price_asc" | "price_desc";
  limit?: number;
  offset?: number;
}): Promise<ApiResponse<StationWithDistance[]>> {
  const search = new URLSearchParams();
  if (params) {
    Object.entries(params).forEach(([k, v]) => {
      if (v !== undefined) search.set(k, String(v));
    });
  }
  const qs = search.toString();
  const res = await fetchApi<StationWithDistance[]>(`/api/v1/stations${qs ? `?${qs}` : ""}`);
  return { ...res, data: res.data.map(normalizeStation) };
}

export async function getStation(
  id: string,
): Promise<ApiResponse<Station>> {
  const res = await fetchApi<Station>(`/api/v1/stations/${id}`);
  return { ...res, data: normalizeStation(res.data) };
}

export async function getBrands(): Promise<ApiResponse<string[]>> {
  return fetchApi("/api/v1/brands");
}

export async function getMetadata(): Promise<
  ApiResponse<Record<AustralianState, StateMetadata>>
> {
  return fetchApi("/api/v1/metadata");
}

/**
 * Daily price trend for a state. History is captured per state, so the series
 * is a state-level daily aggregate — not suburb-specific. `fuel` narrows the
 * series to a single fuel type.
 */
export async function getTrends(
  state: string,
  fuel?: FuelType,
): Promise<ApiResponse<PriceTrend>> {
  const search = new URLSearchParams({ state });
  if (fuel) search.set("fuel", fuel);
  return fetchApi(`/api/v1/trends?${search.toString()}`);
}
