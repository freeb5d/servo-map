import { DATA_SOURCES, type AustralianState, type StationWithDistance } from "@servo-map/shared";

/** The state most stations in view belong to; the cycle verdict follows it. */
export function dominantState(stations: readonly StationWithDistance[]): AustralianState | null {
  const counts = new Map<AustralianState, number>();
  for (const s of stations) counts.set(s.state, (counts.get(s.state) ?? 0) + 1);
  let best: AustralianState | null = null;
  let bestCount = 0;
  for (const [state, count] of counts) {
    if (count > bestCount) {
      best = state;
      bestCount = count;
    }
  }
  return best;
}

/** Name of the official feed a price came from. */
export function sourceLabel(state: AustralianState): string {
  return DATA_SOURCES[state].name;
}

/** Mean position of the stations; the distance origin for a searched suburb. Null when empty. */
export function centroid(stations: readonly StationWithDistance[]): { lat: number; lng: number } | null {
  if (stations.length === 0) return null;
  const sum = stations.reduce((acc, s) => ({ lat: acc.lat + s.lat, lng: acc.lng + s.lng }), { lat: 0, lng: 0 });
  return { lat: sum.lat / stations.length, lng: sum.lng / stations.length };
}
