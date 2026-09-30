import type { AustralianState, PriceSnapshot, Station } from "@servo-map/shared";

/**
 * Writes one ingest run into the servo-map-prices D1 database (decision 0006).
 *
 * The database does the diffing: rows go in as JSON through json_each, and each upsert only
 * writes when a value changed, so an unchanged price costs a read but no billed write. The
 * executor is injected so the same SQL runs over D1's REST API in the ingest script and over
 * node:sqlite in tests.
 */

/** Runs one statement and reports how many rows it wrote (D1 meta.rows_written). */
export type SqlExecutor = (sql: string, params: unknown[]) => Promise<{ rowsWritten: number }>;

/** Rows per statement: keeps each JSON parameter far below D1's 2 MB value limit. */
export const SYNC_CHUNK_SIZE = 1000;

export type IngestStatus = "written" | "guarded" | "failed";

export interface IngestRunRecord {
  state: AustralianState;
  status: IngestStatus;
  stationCount: number;
  rowsWritten: number;
  detail?: string;
}

const UPSERT_STATIONS = `
INSERT INTO stations (id, state, name, brand, address, suburb, postcode, lat, lng, first_seen_at, last_seen_on)
SELECT json_extract(value, '$[0]'), json_extract(value, '$[1]'), json_extract(value, '$[2]'),
       json_extract(value, '$[3]'), json_extract(value, '$[4]'), json_extract(value, '$[5]'),
       json_extract(value, '$[6]'), json_extract(value, '$[7]'), json_extract(value, '$[8]'), ?2, ?3
FROM json_each(?1) WHERE true
ON CONFLICT (id) DO UPDATE SET
  name = excluded.name, brand = excluded.brand, address = excluded.address,
  suburb = excluded.suburb, postcode = excluded.postcode, lat = excluded.lat, lng = excluded.lng,
  last_seen_on = excluded.last_seen_on
WHERE stations.name <> excluded.name OR stations.brand <> excluded.brand
   OR stations.address <> excluded.address OR stations.suburb <> excluded.suburb
   OR stations.postcode <> excluded.postcode OR stations.lat <> excluded.lat
   OR stations.lng <> excluded.lng OR stations.last_seen_on <> excluded.last_seen_on`;

// reported_at alone never triggers a write: WA stamps every fetch, so it changes each run.
const UPSERT_PRICES = `
INSERT INTO current_prices (station_id, fuel, price, reported_at, observed_at)
SELECT json_extract(value, '$[0]'), json_extract(value, '$[1]'), json_extract(value, '$[2]'),
       json_extract(value, '$[3]'), ?2
FROM json_each(?1) WHERE true
ON CONFLICT (station_id, fuel) DO UPDATE SET
  price = excluded.price, reported_at = excluded.reported_at, observed_at = excluded.observed_at
WHERE current_prices.price <> excluded.price`;

const UPSERT_DAILY = `
INSERT INTO daily_prices (state, fuel, date, min, avg, max, station_count)
SELECT ?2, json_extract(value, '$[0]'), json_extract(value, '$[1]'), json_extract(value, '$[2]'),
       json_extract(value, '$[3]'), json_extract(value, '$[4]'), json_extract(value, '$[5]')
FROM json_each(?1) WHERE true
ON CONFLICT (state, fuel, date) DO UPDATE SET
  min = excluded.min, avg = excluded.avg, max = excluded.max, station_count = excluded.station_count
WHERE daily_prices.min <> excluded.min OR daily_prices.avg <> excluded.avg
   OR daily_prices.max <> excluded.max OR daily_prices.station_count <> excluded.station_count`;

const INSERT_RUN = `
INSERT OR REPLACE INTO ingest_runs (run_at, state, status, station_count, rows_written, detail)
VALUES (?1, ?2, ?3, ?4, ?5, ?6)`;

function chunk<T>(rows: T[]): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < rows.length; i += SYNC_CHUNK_SIZE) {
    chunks.push(rows.slice(i, i + SYNC_CHUNK_SIZE));
  }
  return chunks;
}

async function runChunked(
  exec: SqlExecutor,
  sql: string,
  rows: unknown[],
  extraParams: unknown[],
): Promise<number> {
  let written = 0;
  for (const part of chunk(rows)) {
    written += (await exec(sql, [JSON.stringify(part), ...extraParams])).rowsWritten;
  }
  return written;
}

/**
 * Upserts one state's stations, prices and daily snapshots. Returns the rows written.
 * `runAt` stamps first_seen_at and observed_at; its UTC date is the station's last_seen_on.
 */
export async function syncStatePrices(
  exec: SqlExecutor,
  stations: Station[],
  snapshots: PriceSnapshot[],
  state: AustralianState,
  runAt: Date,
): Promise<number> {
  const runIso = runAt.toISOString();
  const runDate = runIso.slice(0, 10);

  const stationRows = stations.map((s) => [
    s.id, s.state, s.name, s.brand, s.address, s.suburb, s.postcode, s.lat, s.lng,
  ]);
  const priceRows = stations.flatMap((s) =>
    s.prices.map((p) => [s.id, p.fuel, p.price, p.updated_at]),
  );
  const dailyRows = snapshots.map((d) => [
    d.fuel, d.date, d.min, d.avg, d.max, d.station_count,
  ]);

  let written = await runChunked(exec, UPSERT_STATIONS, stationRows, [runIso, runDate]);
  written += await runChunked(exec, UPSERT_PRICES, priceRows, [runIso]);
  written += await runChunked(exec, UPSERT_DAILY, dailyRows, [state]);
  return written;
}

/** Records how each state fared in one ingest run. */
export async function recordIngestRuns(
  exec: SqlExecutor,
  runAt: Date,
  records: IngestRunRecord[],
): Promise<void> {
  const runIso = runAt.toISOString();
  for (const r of records) {
    await exec(INSERT_RUN, [
      runIso, r.state, r.status, r.stationCount, r.rowsWritten, r.detail ?? null,
    ]);
  }
}
