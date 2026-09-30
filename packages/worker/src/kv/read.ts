import type {
  Station,
  StateMetadata,
  AustralianState,
  PriceSnapshot,
} from "@servo-map/shared";
import { AUSTRALIAN_STATES } from "@servo-map/shared";
import { KV_KEYS } from "./keys";

export async function readStationsByState(
  kv: KVNamespace,
  state: AustralianState,
): Promise<Station[]> {
  return (await kv.get<Station[]>(KV_KEYS.stationsByState(state), "json")) ?? [];
}

async function findInStateChunk(kv: KVNamespace, id: string): Promise<Station | null> {
  const prefix = id.split("-")[0];
  if (!(AUSTRALIAN_STATES as readonly string[]).includes(prefix)) return null;
  const stations = await readStationsByState(kv, prefix as AustralianState);
  return stations.find((s) => s.id === id) ?? null;
}

/**
 * Ids a station may have moved to. Until 2026-10 the NSW FuelCheck feed's ACT stations were
 * served as "nsw-<code>"; they are now "act-<code>". Saved stations and links still hold the
 * old ids, so those resolve to the station under its current id, which clients then adopt.
 */
function currentIdsFor(id: string): string[] {
  return id.startsWith("nsw-") ? [`act-${id.slice(4)}`] : [];
}

/**
 * Read a single station. Station ids are "{state}-{source_id}", so derive the
 * state and resolve from that state's chunk — we no longer store per-station KV
 * keys (the chunk is the single source of truth; cuts ingest writes ~100x).
 * A retired id resolves to the station under its current id (see currentIdsFor).
 */
export async function readStationById(
  kv: KVNamespace,
  id: string,
): Promise<Station | null> {
  const station = await findInStateChunk(kv, id);
  if (station) return station;
  for (const current of currentIdsFor(id)) {
    const moved = await findInStateChunk(kv, current);
    if (moved) return moved;
  }
  return null;
}

export async function readBrands(kv: KVNamespace): Promise<string[]> {
  return (await kv.get<string[]>(KV_KEYS.brands, "json")) ?? [];
}

export async function readMetadata(
  kv: KVNamespace,
): Promise<Record<string, StateMetadata>> {
  return (await kv.get<Record<string, StateMetadata>>(KV_KEYS.metadata, "json")) ?? {};
}

/** Read the rolling daily price-snapshot series for a state */
export async function readPriceHistory(
  kv: KVNamespace,
  state: AustralianState,
): Promise<PriceSnapshot[]> {
  return (
    (await kv.get<PriceSnapshot[]>(KV_KEYS.priceHistory(state), "json")) ?? []
  );
}

/** Read cached reference data (e.g. NSW station reference), returns null if expired */
export async function readRefData<T>(
  kv: KVNamespace,
  state: AustralianState,
): Promise<T | null> {
  return kv.get<T>(KV_KEYS.refData(state), "json");
}
