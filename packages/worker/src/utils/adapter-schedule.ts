import type { StateMetadata } from "@servo-map/shared";
import type { StateAdapter } from "../adapters/types";

/**
 * Whether the ingest should call this adapter now.
 *
 * An adapter without `minIntervalMinutes` is always due. One with it is due once any state it
 * covers has no recorded update, or its oldest update is at least that many minutes old.
 */
export function isAdapterDue(
  adapter: Pick<StateAdapter, "states" | "minIntervalMinutes">,
  metadata: Record<string, StateMetadata>,
  now: Date,
): boolean {
  if (!adapter.minIntervalMinutes) return true;

  let oldest = Infinity;
  for (const state of adapter.states) {
    const updated = Date.parse(metadata[state]?.last_updated ?? "");
    if (Number.isNaN(updated)) return true;
    oldest = Math.min(oldest, updated);
  }
  return now.getTime() - oldest >= adapter.minIntervalMinutes * 60_000;
}
