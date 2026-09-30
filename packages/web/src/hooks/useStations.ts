"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import type {
  StationWithDistance,
  FuelType,
  ApiResponse,
  PaginationMeta,
} from "@servo-map/shared";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "";
const DEBOUNCE_MS = 300;

interface UseStationsOptions {
  fuel?: FuelType;
  lat?: number | null;
  lng?: number | null;
  radius?: number;
  q?: string;
  limit?: number;
}

interface UseStationsResult {
  stations: StationWithDistance[];
  loading: boolean;
  error: string | null;
  total: number;
  /** 搜索无结果时为 true */
  noResults: boolean;
  refresh: () => void;
}

export function useStations(opts: UseStationsOptions): UseStationsResult {
  const [stations, setStations] = useState<StationWithDistance[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [total, setTotal] = useState(0);
  const [noResults, setNoResults] = useState(false);
  const abortRef = useRef<AbortController | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const fetchStations = useCallback(async () => {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    setLoading(true);
    setError(null);

    const params = new URLSearchParams();
    if (opts.fuel) params.set("fuel", opts.fuel);
    if (opts.lat != null && opts.lng != null) {
      params.set("lat", String(opts.lat));
      params.set("lng", String(opts.lng));
      params.set("radius", String(opts.radius ?? 20));
    }
    if (opts.q) params.set("q", opts.q);
    params.set("limit", String(opts.limit ?? 200));
    if (opts.fuel) params.set("sort", "price_asc");

    try {
      const res = await fetch(
        `${API_BASE}/api/v1/stations?${params}`,
        { signal: controller.signal },
      );
      if (!res.ok) throw new Error(`API ${res.status}`);

      const json: ApiResponse<StationWithDistance[]> & { meta?: PaginationMeta } =
        await res.json();

      if (!controller.signal.aborted) {
        const isSearch = !!opts.q;
        const empty = json.data.length === 0;
        setNoResults(isSearch && empty);
        // 搜索无结果时保留当前站点，不清空地图
        if (!(isSearch && empty)) {
          setStations(json.data);
          setTotal(json.meta?.total ?? json.data.length);
        }
      }
    } catch (err: unknown) {
      if (err instanceof DOMException && err.name === "AbortError") return;
      setError(err instanceof Error ? err.message : "Failed to fetch");
    } finally {
      if (!controller.signal.aborted) setLoading(false);
    }
  }, [opts.fuel, opts.lat, opts.lng, opts.radius, opts.q, opts.limit]);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(fetchStations, DEBOUNCE_MS);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      abortRef.current?.abort();
    };
  }, [fetchStations]);

  return { stations, loading, error, total, noResults, refresh: fetchStations };
}
