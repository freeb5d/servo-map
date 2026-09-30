import { describe, it, expect, beforeEach } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import type { Station, PriceSnapshot } from "@servo-map/shared";
import { syncStatePrices, recordIngestRuns, SYNC_CHUNK_SIZE, type SqlExecutor } from "../sync";

// Loaded through require: Vite does not resolve the node:sqlite builtin as an import.
const { DatabaseSync } = createRequire(import.meta.url)("node:sqlite") as typeof import("node:sqlite");

const MIGRATION = fileURLToPath(
  new URL("../../../migrations-prices/0001_price_history.sql", import.meta.url),
);

type Db = InstanceType<typeof DatabaseSync>;

/** Runs the real migration and SQL on in-memory SQLite, the engine D1 is built on. */
function createDb(): { db: Db; exec: SqlExecutor; calls: string[] } {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(MIGRATION, "utf8"));
  const calls: string[] = [];
  const exec: SqlExecutor = async (sql, params) => {
    calls.push(sql);
    const result = db.prepare(sql).run(...(params as (string | number | null)[]));
    return { rowsWritten: Number(result.changes) };
  };
  return { db, exec, calls };
}

function station(id: string, prices: Station["prices"], overrides: Partial<Station> = {}): Station {
  return {
    id,
    name: `Station ${id}`,
    brand: "Ampol",
    address: "1 Test St",
    suburb: "Testville",
    state: "nsw",
    postcode: "2000",
    lat: -33.8,
    lng: 151.2,
    prices,
    ...overrides,
  };
}

const RUN_1 = new Date("2026-10-01T00:00:00.000Z");
const RUN_2 = new Date("2026-10-01T00:15:00.000Z");
const NEXT_DAY = new Date("2026-10-02T00:00:00.000Z");

function rows<T>(db: Db, sql: string): T[] {
  return db.prepare(sql).all() as T[];
}

describe("syncStatePrices", () => {
  let db: Db;
  let exec: SqlExecutor;
  let calls: string[];

  beforeEach(() => {
    ({ db, exec, calls } = createDb());
  });

  it("stores stations, current prices and a first price change on the first run", async () => {
    const stations = [
      station("nsw-1", [
        { fuel: "U91", price: 179.9, updated_at: "2026-09-30T23:50:00Z" },
        { fuel: "Diesel", price: 199.9, updated_at: "2026-09-30T23:50:00Z" },
      ]),
    ];

    await syncStatePrices(exec, stations, [], "nsw", RUN_1);

    expect(rows(db, "SELECT id, state, first_seen_at, last_seen_on FROM stations")).toEqual([
      { id: "nsw-1", state: "nsw", first_seen_at: RUN_1.toISOString(), last_seen_on: "2026-10-01" },
    ]);
    expect(rows(db, "SELECT fuel, price FROM current_prices ORDER BY fuel")).toEqual([
      { fuel: "Diesel", price: 199.9 },
      { fuel: "U91", price: 179.9 },
    ]);
    expect(rows(db, "SELECT fuel, price, observed_at FROM price_changes ORDER BY fuel")).toEqual([
      { fuel: "Diesel", price: 199.9, observed_at: RUN_1.toISOString() },
      { fuel: "U91", price: 179.9, observed_at: RUN_1.toISOString() },
    ]);
  });

  it("writes nothing when a later run sees the same stations and prices", async () => {
    const first = [station("nsw-1", [{ fuel: "U91", price: 179.9, updated_at: "t1" }])];
    // Same price with a fresh source timestamp, as WA reports on every fetch.
    const second = [station("nsw-1", [{ fuel: "U91", price: 179.9, updated_at: "t2" }])];

    await syncStatePrices(exec, first, [], "nsw", RUN_1);
    const written = await syncStatePrices(exec, second, [], "nsw", RUN_2);

    expect(written).toBe(0);
    expect(rows(db, "SELECT reported_at, observed_at FROM current_prices")).toEqual([
      { reported_at: "t1", observed_at: RUN_1.toISOString() },
    ]);
    expect(rows(db, "SELECT COUNT(*) AS n FROM price_changes")).toEqual([{ n: 1 }]);
  });

  it("appends a price change only when the price moves", async () => {
    await syncStatePrices(exec, [station("nsw-1", [{ fuel: "U91", price: 179.9, updated_at: "t1" }])], [], "nsw", RUN_1);
    await syncStatePrices(exec, [station("nsw-1", [{ fuel: "U91", price: 169.9, updated_at: "t2" }])], [], "nsw", RUN_2);

    expect(rows(db, "SELECT price, observed_at FROM price_changes ORDER BY observed_at")).toEqual([
      { price: 179.9, observed_at: RUN_1.toISOString() },
      { price: 169.9, observed_at: RUN_2.toISOString() },
    ]);
    expect(rows(db, "SELECT price, reported_at, observed_at FROM current_prices")).toEqual([
      { price: 169.9, reported_at: "t2", observed_at: RUN_2.toISOString() },
    ]);
  });

  it("updates changed station details and moves last_seen_on once per day", async () => {
    await syncStatePrices(exec, [station("nsw-1", [])], [], "nsw", RUN_1);

    expect(await syncStatePrices(exec, [station("nsw-1", [])], [], "nsw", RUN_2)).toBe(0);
    expect(await syncStatePrices(exec, [station("nsw-1", [], { brand: "EG Ampol" })], [], "nsw", RUN_2)).toBe(1);
    expect(await syncStatePrices(exec, [station("nsw-1", [], { brand: "EG Ampol" })], [], "nsw", NEXT_DAY)).toBe(1);

    expect(rows(db, "SELECT brand, first_seen_at, last_seen_on FROM stations")).toEqual([
      { brand: "EG Ampol", first_seen_at: RUN_1.toISOString(), last_seen_on: "2026-10-02" },
    ]);
  });

  it("upserts daily snapshots and rewrites a day only when its numbers change", async () => {
    const snapshot: PriceSnapshot = {
      date: "2026-10-01", fuel: "U91", min: 160, avg: 175.5, max: 199, station_count: 3,
    };

    await syncStatePrices(exec, [], [snapshot], "nsw", RUN_1);
    expect(await syncStatePrices(exec, [], [snapshot], "nsw", RUN_2)).toBe(0);
    await syncStatePrices(exec, [], [{ ...snapshot, min: 158 }], "nsw", RUN_2);

    expect(rows(db, "SELECT state, fuel, date, min, avg, max, station_count FROM daily_prices")).toEqual([
      { state: "nsw", fuel: "U91", date: "2026-10-01", min: 158, avg: 175.5, max: 199, station_count: 3 },
    ]);
  });

  it("splits large states into chunks of SYNC_CHUNK_SIZE rows", async () => {
    const many = Array.from({ length: SYNC_CHUNK_SIZE + 1 }, (_, i) =>
      station(`nsw-${i}`, [{ fuel: "U91", price: 170, updated_at: "t" }]),
    );

    await syncStatePrices(exec, many, [], "nsw", RUN_1);

    // Two station chunks and two price chunks; no daily rows means no daily statement.
    expect(calls).toHaveLength(4);
    expect(rows(db, "SELECT COUNT(*) AS n FROM current_prices")).toEqual([{ n: SYNC_CHUNK_SIZE + 1 }]);
  });
});

describe("recordIngestRuns", () => {
  it("stores one row per state and rejects an unknown status", async () => {
    const { db, exec } = createDb();

    await recordIngestRuns(exec, RUN_1, [
      { state: "nsw", status: "written", stationCount: 2386, rowsWritten: 120 },
      { state: "qld", status: "failed", stationCount: 0, rowsWritten: 0, detail: "QLD API error: 401" },
    ]);

    expect(rows(db, "SELECT state, status, station_count, rows_written, detail FROM ingest_runs ORDER BY state")).toEqual([
      { state: "nsw", status: "written", station_count: 2386, rows_written: 120, detail: null },
      { state: "qld", status: "failed", station_count: 0, rows_written: 0, detail: "QLD API error: 401" },
    ]);
    await expect(
      recordIngestRuns(exec, RUN_2, [
        { state: "wa", status: "unknown" as never, stationCount: 0, rowsWritten: 0 },
      ]),
    ).rejects.toThrow(/CHECK constraint/);
  });
});
