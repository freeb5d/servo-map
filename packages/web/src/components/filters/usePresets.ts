"use client";

import { useCallback } from "react";
import {
  DEFAULT_FILTERS,
  describeFilters,
  parseFilters,
  serializeFilters,
  type MapFilters,
} from "@/lib/filters";
import { useLocalStorage } from "@/hooks/useLocalStorage";

const MAX_PRESETS = 6;

export interface Preset {
  /** Serialised filters (a query string), the stored form. */
  key: string;
  label: string;
  filters: MapFilters;
}

/** Filters saved as one-tap presets. Search and sort belong to the moment, so they are not saved. */
export function usePresets() {
  const [keys, setKeys] = useLocalStorage<string[]>("servo-map:filter-presets", []);

  const presets: Preset[] = keys
    .map((key) => {
      const filters = parseFilters(new URLSearchParams(key));
      return { key, label: describeFilters(filters), filters };
    })
    // A stored key that no longer parses to any filter would render as an unnamed chip.
    .filter((p) => p.label !== "");

  const save = useCallback(
    (filters: MapFilters) => {
      const key = serializeFilters({ ...filters, q: DEFAULT_FILTERS.q, sort: DEFAULT_FILTERS.sort }).toString();
      if (!key) return;
      setKeys((prev) => (prev.includes(key) ? prev : [...prev, key].slice(-MAX_PRESETS)));
    },
    [setKeys],
  );

  const remove = useCallback(
    (key: string) => setKeys((prev) => prev.filter((k) => k !== key)),
    [setKeys],
  );

  return { presets, save, remove };
}
