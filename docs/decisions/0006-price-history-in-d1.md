# 0006 — Price history in Cloudflare D1

- Date: 2026-09-30
- Status: **accepted**
- Owner: Henry Chen
- Evidence: live checks on 2026-09-30 against `api.servo-map.com` and the new database (below)

## Problem

KV keeps only the latest price per station, rewritten every 15 minutes, plus one state-wide
min/avg/max per fuel per day for 90 days. Per-station history, brand or suburb trends, and a
record of which runs failed are lost. The daily series already has a 47-day hole
(2026-08-02 to 2026-09-17) from cron stalls, and nothing records that it happened.

## Options

Where to keep history:

- A. More KV keys. No queries; every station series is a read-modify-write of a whole value.
- B. D1, written by the ingest script over the REST API. SQL queries; free plan allows
  100,000 rows written and 5 million read a day, 500 MB per database, 5 GB per account.
- C. R2 files (daily JSON dumps). Cheap, but no queries without a second system.

Which database:

- B1. Add tables to `servo-map-accounts` (decision 0004). One binding, joins with saved stations.
- B2. A separate `servo-map-prices`. No cross-database joins.

How to stay inside the write budget: writing every price every run is about 1 million rows a
day for NSW and WA alone. Writing only changes needs a diff; doing it in the database (upsert
with a `WHERE` that skips unchanged rows, a trigger appending to the history table) keeps one
source of truth and costs reads, not writes.

## Choice

**B with B2.** Price history lives in its own D1 database `servo-map-prices`:

- The 500 MB cap applies per database, and a full database refuses every insert; history must
  never be able to stop sign-in and account writes.
- D1 runs one query at a time per database; the ingest's bulk upserts would queue account
  requests behind them.
- Account data is personal (email, rounded home location); prices are public. They get different
  retention and access.
- The alert job, if it later reads prices from D1, queries `current_prices` by station ids
  separately instead of joining.

Schema: `packages/worker/migrations-prices/0001_price_history.sql`. Tables are `WITHOUT ROWID`
with no secondary index, because each index entry is a billed write. KV stays the read path;
D1 failures only log.

## Measured

On 2026-09-30, syncing the live data twice (3,380 stations, 10,216 prices):

- The first run wrote 23,822 rows. The second run, with no price changes, wrote 0.
- The database was 2.4 MB after the first run plus the 750 daily rows backfilled from KV.

Daily writes are therefore about 2 × the number of price changes, plus up to 3,380 station
rows at the first run of each UTC day, plus the `ingest_runs` rows. Review this record if
`ingest_runs.rows_written` summed over a day passes 60,000, or the database passes 300 MB.
