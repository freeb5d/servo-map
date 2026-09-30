# Adding a State Adapter

> Last reviewed: 2026-04-22
> Status: NSW, ACT, TAS and WA live; QLD adapter waiting on its token. VIC / SA / NT pending.

This is the repo's most repeated work. Follow the playbook — do not invent new patterns.

---

## The contract

Every adapter implements `StateAdapter` from `packages/worker/src/adapters/types.ts`:

```ts
export interface StateAdapter {
  /** Which states this adapter covers (can be more than one if the upstream spans multiple, e.g. the NSW feed covers ACT). */
  readonly states: readonly AustralianState[];

  /** Minimum minutes between fetches, for upstreams with a call quota (TAS: 120). Omit to fetch every run. */
  readonly minIntervalMinutes?: number;

  /** Fetch all stations with current prices. Throws on upstream failure. */
  fetchStations(env: Env): Promise<Station[]>;
}
```

Output shape (from `@servo-map/shared`):

```ts
interface Station {
  id: string;             // Format: "{state}-{source_id}"  ← mandatory
  name: string;
  brand: string;
  address: string;
  suburb: string;
  state: AustralianState;
  postcode: string;
  lat: number;
  lng: number;
  prices: FuelPrice[];    // { fuel: FuelType; price: number (cents/L); updated_at: ISO 8601 }
}
```

**Invariants:**

- `id` is globally unique and prefixed with the state code. Must be deterministic — re-running the adapter on the same upstream data must produce the same id.
- `lat`/`lng` must be non-zero, within Australia's bounding box.
- `prices[].price` is in **cents per litre** (not dollars, not 0.1-cent units). QLD's upstream returns 0.1-cent; divide by 10.
- `prices[].updated_at` is ISO 8601 UTC.
- `state` must be a literal `AustralianState`. No free strings.
- `prices[].fuel` must map through `packages/worker/src/utils/fuel-map.ts` (one mapper per upstream).
- `name`, `address` and `suburb` pass through `titleCasePlace` (`packages/worker/src/utils/place-names.ts`), so all-caps feed text ("REVESBY") is stored title-cased and clients display it as served. `brand` is left as sent. Derive ids from the raw upstream text, never the recased copy.

---

## Step-by-step: adding a new state (e.g. WA)

### 1. Secure credentials

- Add the API key / token to your local `packages/worker/.dev.vars` (and the `.dev.vars.example`).
- Add to `packages/worker/src/env.ts`:
  ```ts
  export interface Env {
    KV: KVNamespace;
    NSW_API_KEY: string;
    NSW_API_AUTH: string;
    QLD_API_TOKEN: string;
    WA_API_KEY: string;   // new
  }
  ```
- Add a matching GitHub Actions secret (`WA_API_KEY`) and wire it in `.github/workflows/deploy-worker.yml` and `.github/workflows/fetch-data.yml`.
- Document it in `docs/claude/security.md`.

### 2. Describe upstream raw types

Append to `packages/worker/src/adapters/types.ts`:

```ts
// --- WA FuelWatch raw types ---
export interface WaStation { /* ... */ }
export interface WaResponse { /* ... */ }
```

Keep raw types **in the adapter module** — they must not be re-exported and they must not leak into `@servo-map/shared`.

### 3. Extend the fuel-type mapper

Open `packages/worker/src/utils/fuel-map.ts` and add `mapWaFuelType(upstream: string): FuelType | null`. Return `null` for unsupported types — adapters drop them silently (see NSW/QLD implementations).

### 4. Write the adapter

Create `packages/worker/src/adapters/wa.ts`. Use `packages/worker/src/adapters/qld.ts` as the template — it's the simpler of the two. Keep the structure:

```ts
const BASE_URL = "https://...";

async function fetchWithAuth<T>(url: string, ...): Promise<T> { ... }

export const waAdapter: StateAdapter = {
  states: ["wa"] as const,
  async fetchStations(env): Promise<Station[]> {
    // 1. Fetch sites + prices (Promise.all if two calls)
    // 2. Aggregate prices by site id
    // 3. Build Station[] with stable "wa-<id>" ids
    // 4. Drop sites without lat/lng
    return stations;
  },
};
```

**Style rules:**

- All upstream calls live in one `fetchWithAuth` helper in the same file.
- Throw on non-OK responses with a state-prefixed message: `throw new Error("WA API error: ...")`.
- Do not retry inside the adapter — the cron caller gets one shot every 15 minutes and will try again.
- If the upstream uses stale "daily price for tomorrow" semantics (FuelWatch), comment it clearly and prefer `updated_at = now` over a fabricated timestamp.

### 5. Register the adapter

Open `packages/worker/src/adapters/index.ts`:

```ts
import { waAdapter } from "./wa";
export const adapters: readonly StateAdapter[] = [nswAdapter, qldAdapter, waAdapter];
```

That's it — the GitHub Actions ingest (`scripts/fetch-data.ts`) imports this list directly, so a new adapter is picked up with no further wiring.

### 6. Add tests

At minimum, one smoke test in `packages/worker/src/adapters/__tests__/wa.test.ts`:

- Given a recorded fixture of the raw upstream response, `waAdapter.fetchStations` produces a valid `Station[]`.
- Stations without lat/lng are filtered out.
- `id` follows the `wa-<source_id>` pattern.
- Prices are in cents/L (scale check).

See `docs/claude/testing.md` for framework setup.

### 7. Update docs

- Add the row to `plan.md` § Data sources if not already there.
- Mention coverage change in the PR description.
- If the OpenAPI `state` enum is constrained (it is — it lists valid state codes), ensure the new state is listed in `docs/openapi.yaml`.

### 8. Verify locally

```bash
# Put the new secret in .dev.vars
pnpm dev:worker &

# Run the ingest script to populate KV (after exporting env vars):
npx tsx scripts/fetch-data.ts
```

Confirm:

- Logs show `[fetch-data] WA: N stations`.
- `curl http://localhost:8787/api/v1/stations?state=wa | jq '.data | length'` returns N.
- `curl http://localhost:8787/api/v1/metadata | jq .wa` has a fresh `last_updated`.

---

## Checklist

- [ ] Secret added to `env.ts`, `.dev.vars.example`, GH secrets, deploy-worker.yml, fetch-data.yml
- [ ] Raw upstream types in `adapters/types.ts`
- [ ] Fuel mapper added to `utils/fuel-map.ts`
- [ ] Adapter file follows QLD template
- [ ] Stations have stable `{state}-{id}` ids
- [ ] Prices in cents/L (not dollars, not 0.1-cent units)
- [ ] `name` / `address` / `suburb` wrapped in `titleCasePlace`
- [ ] Registered in `adapters/index.ts`
- [ ] Smoke test with recorded fixture
- [ ] `docs/openapi.yaml` state enum updated
- [ ] `plan.md` data-sources row present
- [ ] Verified end-to-end locally before opening PR

---

## Known pitfalls

| Pitfall                                           | Fix                                                                 |
|---------------------------------------------------|---------------------------------------------------------------------|
| Copying QLD's 0.1-cent scale to a different API   | Always verify the upstream's price unit in docs or by inspection     |
| Using upstream ids as global ids                   | Always prefix with state code                                        |
| Forgetting to filter stations with no coordinates | The map cannot render them; drop them in the adapter                 |
| Treating transient 5xx as fatal                    | Do throw — cron retries every 15 min; prior KV data is still served  |
| Hardcoding the state code inside a multi-state adapter (e.g. the NSW feed covers ACT) | Derive it per station; see `stationState` in `adapters/nsw.ts`, which reads the address suffix because FuelCheck labels ACT stations "NSW" |
