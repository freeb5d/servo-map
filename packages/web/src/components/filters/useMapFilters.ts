"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { FILTER_KEYS, parseFilters, serializeFilters, type MapFilters } from "@/lib/filters";

type Update = Partial<MapFilters> | ((prev: MapFilters) => MapFilters);

/**
 * Map filters backed by the URL, so a filtered view can be shared or bookmarked.
 * A local copy answers instantly; router.replace then writes the URL without a scroll
 * or history entry, and a URL change made elsewhere (the top-bar search) is adopted.
 */
export function useMapFilters(): readonly [MapFilters, (update: Update) => void] {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const paramString = params.toString();

  const [state, setState] = useState(() => ({ seen: paramString, filters: parseFilters(params) }));
  // Adopt a URL change made outside this hook, during render so there is no stale frame.
  if (state.seen !== paramString) setState({ seen: paramString, filters: parseFilters(params) });

  // Lets `set` build on the newest filters even when two updates land in one tick.
  const latest = useRef(state.filters);
  useEffect(() => {
    latest.current = state.filters;
  }, [state.filters]);

  const set = useCallback(
    (update: Update) => {
      const next =
        typeof update === "function" ? update(latest.current) : { ...latest.current, ...update };
      // Nothing changed (for example clearing an empty search): skip the navigation.
      if (serializeFilters(next).toString() === serializeFilters(latest.current).toString()) return;
      latest.current = next;
      setState((s) => ({ ...s, filters: next }));

      // Keep query keys the filters do not own (for example a campaign tag).
      const out = new URLSearchParams(window.location.search);
      for (const key of FILTER_KEYS) out.delete(key);
      for (const [key, value] of serializeFilters(next)) out.set(key, value);
      const qs = out.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [router, pathname],
  );

  return [state.filters, set] as const;
}
