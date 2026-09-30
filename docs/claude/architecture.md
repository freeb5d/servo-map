# Architecture

> Last reviewed: 2026-04-22

## Package boundaries

```
┌──────────────────────┐          ┌──────────────────────┐
│  State fuel APIs     │          │   Browser (user)     │
│  (NSW, QLD, ...)     │          │                      │
└──────────┬───────────┘          └──────────┬───────────┘
           │                                 │
           │ HTTPS                           │ HTTPS
           ▼                                 ▼
┌──────────────────────┐          ┌──────────────────────┐
│  Ingest path         │          │  Read path           │
│  scripts/fetch-data  │          │  CF Worker (Hono)    │
│  (GH Actions cron,   │          │  api.servo-map.com   │
│   every 15 min)      │          │                      │
└──────────┬───────────┘          └──────────┬───────────┘
           │ KV REST API                     │ KV binding
           ▼                                 ▼
          ┌───────────────────────────────────────┐
          │  Cloudflare KV (namespace: servo-map) │
          └───────────────────────────────────────┘
                            ▲
                            │ fetch() via NEXT_PUBLIC_API_URL
                            │
          ┌───────────────────────────────────────┐
          │  Next.js (Vercel)                     │
          │  - App Router pages (SSR/ISR)         │
          │  - Mapbox GL (client-only)            │
          │  - /fuel/[state]/[suburb], /station/[id] │
          └───────────────────────────────────────┘
```

## One writer, read-only worker

**`scripts/fetch-data.ts`** is the only path that writes KV — a Node script run by GitHub Actions every 15 minutes. It imports the worker's `StateAdapter` list directly, calls each adapter, and writes to KV via the Cloudflare REST API. The adapters are pure (global `fetch`/`crypto` only; every `@servo-map/shared` import is type-only), so the Node script reuses them with no worker-runtime dependency.

The Hono Worker is **read-only** — it serves `/api/v1/*` from KV and never writes.

> If ingest is ever migrated onto Cloudflare Cron Triggers, re-add a `scheduled` handler that calls the same adapter list and wire `[triggers].crons` in `wrangler.toml` — and disable the `fetch-data.yml` schedule first.

## Shared types

`@servo-map/shared` is a TypeScript-only package. It compiles to `dist/` and both `web` and `worker` depend on it via `workspace:*`.

Authoritative exports (`packages/shared/src/index.ts`):

- `FUEL_TYPES`, `FuelType` — `"U91" | "U95" | "U98" | "E10" | "Diesel"`
- `AUSTRALIAN_STATES`, `AustralianState` — `"nsw" | "qld" | "vic" | "wa" | "sa" | "tas" | "act" | "nt"`
- `Station`, `FuelPrice`, `StationWithDistance`
- `PaginationMeta`, `StateMetadata`
- `ApiResponse<T>`, `ApiErrorResponse`

**Build order matters.** `pnpm --filter @servo-map/shared build` must run before `typecheck`/`build` of the other packages in CI (see `.github/workflows/ci.yml`).

## KV schema

Defined in `packages/worker/src/kv/keys.ts`:

| Key                       | Type                                       | Writer                         | Reader                                    |
|---------------------------|--------------------------------------------|--------------------------------|-------------------------------------------|
| `stations:<state>`        | `Station[]` (JSON)                         | ingest (one write per state)   | `/api/v1/stations` **and** `/stations/:id` (derives state from the id prefix) |
| `brands`                  | `string[]` (JSON, sorted unique)           | ingest                         | `/api/v1/brands`                          |
| `metadata`                | `Record<AustralianState, StateMetadata>`   | ingest (merged)                | `/api/v1/metadata`                        |
| `history:<state>`         | `PriceSnapshot[]` (rolling ~90 days)       | ingest (daily roll-up)         | `/api/v1/trends`                          |
| `ref:<state>`             | adapter-defined, TTL-bounded               | optional adapter cache         | optional adapter cache                    |

> No per-station `station:<id>` key — `/stations/:id` resolves from the state chunk, keeping ingest to ~one KV write per state.

## D1 price history

`servo-map-prices` (binding `PRICES`, schema in `packages/worker/migrations-prices/`, decision 0006) keeps what KV overwrites. The ingest script writes it through `packages/worker/src/prices-db/sync.ts`; no route reads it yet.

| Table            | Row                                           | Written when                              |
|------------------|-----------------------------------------------|-------------------------------------------|
| `stations`       | one per station id                            | details change, or first run of a UTC day |
| `current_prices` | latest price per station and fuel             | the price changes                         |
| `price_changes`  | every price a station has shown (append-only) | by trigger when `current_prices` changes  |
| `daily_prices`   | `PriceSnapshot` per state, fuel and day       | the day's numbers change                  |
| `ingest_runs`    | one per state per run: written/guarded/failed | every run                                 |

**Rules:**

- `metadata` is **merged** with the previous value (`writeMetadata`) so a state that failed to fetch keeps its last-good timestamp.
- `ref:<state>` entries must be written with `expirationTtl` (seconds).
- Never list-scan KV in a hot path. All reads are direct key gets.

## Request pipeline (read path)

```
Browser → GET /api/v1/stations?state=nsw&fuel=U91&sort=price_asc
  → Hono route (packages/worker/src/routes/stations.ts)
  → Validate params (AUSTRALIAN_STATES / FUEL_TYPES allowlist)
  → readStationsByState(kv, state) for each requested state  (Promise.all)
  → Filter in memory: brand, fuel, q, suburb, postcode, radius
  → Compute distance (haversine) when lat/lng supplied
  → Sort by distance OR price (requires fuel param)
  → Paginate (limit default 100, max 500)
  → Return { status: "success", data, meta }
```

Limits: `DEFAULT_LIMIT = 100`, `MAX_LIMIT = 500`. If you change them, update `docs/openapi.yaml`.

## Ingest pipeline (write path)

```
GH Actions cron (every 15 min)
  → scripts/fetch-data.ts
  → for each adapter: adapter.fetchStations(env)   (Promise.allSettled)
  → groupByState(all stations)
  → for each state with data:
       writeStations(kv, state, stations)
       metadata[state] = { last_updated, station_count }
  → writeBrands(kv, uniqueSortedBrands)
  → writeMetadata(kv, metadataUpdates)  (merged)
```

A single adapter failure is logged but does not abort the cycle — the remaining states still update.

## Frontend topology

- `packages/web/src/app/layout.tsx` — root layout, fonts, `<ThemeProvider>`, `<Analytics />`.
- `packages/web/src/app/page.tsx` — landing / map.
- `packages/web/src/app/fuel/[state]/[suburb]/` — SEO suburb pages (ISR).
- `packages/web/src/app/station/[id]/` — per-station page.
- `packages/web/src/lib/api.ts` — the **only** place the web talks to the Worker. All fetches go through `getStations`, `getStation`, `getBrands`.
- `packages/web/src/hooks/useStations.ts` — client-side station state.
- `packages/web/src/components/map/` — Mapbox wrapper. Must remain client-side (`"use client"` + `next/dynamic` where needed).
