"use client";

import { useEffect, useRef, useState } from "react";
import type { Station } from "@servo-map/shared";
import { getStation } from "@/lib/api";
import { recordVisit, type MarksById } from "@/lib/saved";

const MARKS_KEY = "servo-map:saved-prices";

export type SavedEntry =
  | { status: "ok"; station: Station }
  /** The station is no longer reported by its state's feed. */
  | { status: "missing" }
  | { status: "error" };

interface SavedStations {
  entries: Record<string, SavedEntry>;
  /** Prices as they were at the previous visit, captured before this visit overwrote them. */
  baseline: MarksById;
  loading: boolean;
}

function readMarks(): MarksById {
  try {
    const raw = window.localStorage.getItem(MARKS_KEY);
    return raw ? (JSON.parse(raw) as MarksById) : {};
  } catch {
    return {};
  }
}

function writeMarks(marks: MarksById): void {
  try {
    window.localStorage.setItem(MARKS_KEY, JSON.stringify(marks));
  } catch {
    // Storage full or blocked: the list still renders, it just cannot show changes next time.
  }
}

async function loadEntry(id: string): Promise<[string, SavedEntry]> {
  try {
    const { data } = await getStation(id);
    return [id, { status: "ok", station: data }];
  } catch (err) {
    const missing = err instanceof Error && err.message.startsWith("API error: 404");
    return [id, { status: missing ? "missing" : "error" }];
  }
}

/**
 * Loads each saved station by id and, once per station, compares its prices with the ones seen on
 * the previous visit. The comparison baseline is captured before the new prices are stored, so
 * the change stays visible for the whole visit and only resets on the next one.
 */
export function useSavedStations(ids: readonly string[], ready: boolean): SavedStations {
  const [entries, setEntries] = useState<Record<string, SavedEntry>>({});
  const [baseline, setBaseline] = useState<MarksById>({});
  const requested = useRef(new Set<string>());
  const idsKey = ids.join(",");

  useEffect(() => {
    if (!ready) return;
    const todo = ids.filter((id) => !requested.current.has(id));
    if (todo.length === 0) return;
    todo.forEach((id) => requested.current.add(id));

    Promise.all(todo.map(loadEntry)).then((results) => {
      const stored = readMarks();
      const seen: MarksById = {};
      for (const id of todo) if (stored[id]) seen[id] = stored[id];

      setEntries((prev) => ({ ...prev, ...Object.fromEntries(results) }));
      setBaseline((prev) => ({ ...seen, ...prev }));

      const stations = results.flatMap(([, e]) => (e.status === "ok" ? [e.station] : []));
      const next = recordVisit(stored, stations, new Date(), ids);
      if (next !== stored) writeMarks(next);
    });
    // `ids` is captured through idsKey; the array identity changes on every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [idsKey, ready]);

  const loading = ready && ids.some((id) => !(id in entries));
  return { entries, baseline, loading };
}
