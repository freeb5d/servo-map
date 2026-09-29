# Security

> Last reviewed: 2026-04-22

## Secret locations

| Environment        | Location                                         | Format                  |
|--------------------|--------------------------------------------------|-------------------------|
| Worker (local)     | `packages/worker/.dev.vars`                      | `KEY=value` per line    |
| Worker (prod)      | CF — `wrangler secret put KEY`                   | Opaque after set        |
| Web (local)        | `packages/web/.env.local`                        | `KEY=value` per line    |
| Web (prod)         | Vercel project env (build-time)                  | Injected at deploy      |
| CI (GH Actions)    | Repo secrets (Settings → Secrets → Actions)      | Referenced as `${{ secrets.NAME }}` |
| iOS release (local)| 1Password `op://02 Personal Production/App Store Connect API Key - kioku-ios-ops` (team App Manager key, shared with kioku-ios) | Read by `apps/ios/scripts/beta.sh` into the environment; the `.p8` exists only in ignored `apps/ios/build/` during a lane |
| iOS push (future)  | 1Password `02 Personal Production / jade-apns` (the team's APNs auth key; one key serves every app on team `BZVKP6884D`) | For the server that will send price alerts |

**Never commit** `.dev.vars`, `.env`, `.env.local`, or anything under `.wrangler/`. `.gitignore` already excludes them — verify before every commit.

## Publishable vs secret

| Name                        | Class       | Notes                                                              |
|-----------------------------|-------------|--------------------------------------------------------------------|
| `NEXT_PUBLIC_MAPBOX_TOKEN`  | public      | Shipped to the browser. Scope it: restrict to `servo-map.com` and any preview domains in the Mapbox account. |
| `NEXT_PUBLIC_API_URL`       | public      | Shipped to the browser. Not sensitive.                             |
| `NSW_API_KEY`, `NSW_API_AUTH`, `QLD_API_TOKEN` | secret | Worker-side only. Never `NEXT_PUBLIC_*`.              |
| `VERCEL_TOKEN`, `CLOUDFLARE_API_TOKEN` | secret | CI only.                                                   |

`NEXT_PUBLIC_*` is leaky by definition (bundled into client JS). Anything truly secret must not use this prefix.

## Rotation procedure

### NSW (FuelCheck)

1. Log in to `api.nsw.gov.au` → My Apps → generate a new key for the ServoMap app.
2. Update both `NSW_API_KEY` and `NSW_API_AUTH` in:
   - GitHub repo secrets
   - `packages/worker/.dev.vars` (local)
3. Push new secrets to CF: `wrangler secret put NSW_API_KEY --config packages/worker/wrangler.toml` (deploy workflow does this automatically on next merge).
4. Revoke the old key on the NSW portal after verifying the new key works against `/api/v1/metadata`.

### QLD

Same pattern — regenerate a subscriber token at `fuelpricesqld.com.au`, update `QLD_API_TOKEN` in GH secrets + `.dev.vars`, redeploy.

### Mapbox

1. Mapbox account → Tokens → create a new restricted token (URL-restricted to production and preview domains).
2. Update `NEXT_PUBLIC_MAPBOX_TOKEN` in Vercel project env and GH secrets.
3. Trigger a redeploy. Verify map loads.
4. Revoke the old token.

### Cloudflare API token

1. CF dashboard → My Profile → API Tokens → create a new token with `Workers Scripts:Edit` + `Workers KV Storage:Edit`.
2. Update `CLOUDFLARE_API_TOKEN` in GH secrets.
3. Verify next deploy succeeds, then roll the old token.

### Vercel token

1. Vercel → Account Settings → Tokens → create new.
2. Update `VERCEL_TOKEN` in GH secrets.
3. Verify `deploy-web.yml` succeeds on `workflow_dispatch`, then roll the old token.

## Things we never log

- Full request bodies to upstream APIs (they include auth headers indirectly when retried).
- Full response bodies from upstream APIs (PII is unlikely, but they may contain tokens/keys embedded in error messages).
- `.dev.vars` contents, ever.
- CF account id and KV namespace id in user-facing contexts. (They're in `wrangler.toml` — that's fine; just don't paste into Slack.)

## Input validation

- All Worker routes validate query params against the shared enums (`AUSTRALIAN_STATES`, `FUEL_TYPES`) before touching KV — see `packages/worker/src/routes/stations.ts`. Preserve this pattern when adding routes.
- Never interpolate user input into a KV key. Use `KV_KEYS.*` builders that take typed values.
- Never `fetch()` a URL constructed from user input. All upstream URLs are constants inside adapter files.

## CORS

Currently `hono/cors()` with defaults (`Access-Control-Allow-Origin: *`). This is fine while the API is fully public and read-only. **Before adding any write endpoint, restrict the origin allowlist.**

## Dependencies

- Run `pnpm audit` periodically. Fix `high` and `critical` before merging.
- Pin only when a floating minor breaks you; otherwise keep carets so patch releases flow in.
- Avoid dependencies that expand the client bundle without measurable benefit (Mapbox is already large).

## Reporting issues

Send to `security@servo-map.com` once the domain is live. Until then, open a **private** security advisory on the GitHub repo.
