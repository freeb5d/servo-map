# ServoMap — Project Constitution

> Stable, high-signal context for any agent working in this repo.
> For product narrative and roadmap, see [`plan.md`](./plan.md).
> For deep dives on any topic, follow the pointers in **§ Rule docs** below.

---

## 1. What this is

ServoMap is an Australia-wide fuel price map. It aggregates every state's
fuel reporting API into one normalised dataset, serves it through a
Cloudflare Worker, and renders it in a Next.js + Mapbox frontend and a
SwiftUI iOS app.

- **Domain:** `servo-map.com` (pending)
- **API:** `api.servo-map.com` (Cloudflare)
- **Status:** NSW, ACT, TAS + WA live; QLD / VIC / SA / NT pending (see `plan.md`). iOS app in TestFlight.
- **Cost target:** $0/month on free tiers

---

## 2. Stack

| Layer       | Choice                                     |
|-------------|--------------------------------------------|
| Frontend    | Next.js 15 (App Router), React 19, Tailwind 4, Mapbox GL, `@vercel/analytics` |
| iOS         | SwiftUI (iOS 27), MapKit, WidgetKit, App Intents; xcodegen; fastlane → TestFlight |
| Backend     | Cloudflare Worker + Hono 4, KV for cache   |
| Types       | Shared TS package (`@servo-map/shared`)    |
| Ingest cron | GitHub Actions (`*/15 * * * *`) → `scripts/fetch-data.ts` → CF KV REST API |
| Deploy      | Vercel (web), Wrangler (worker)            |
| Monorepo    | pnpm workspaces                             |
| CI          | GitHub Actions: typecheck · lint · build-web · test |

---

## 3. Package map

```
servo-map/
├── apps/
│   └── ios/         # SwiftUI app. xcodegen project.yml; fastlane lanes; version in Config/Version.xcconfig.
├── design/
│   ├── app-icon/    # generate.py: one fuel-gauge geometry → favicon, web mark, iOS Icon Composer icon.
│   └── brand-logos/ # Brand logo PNGs + SOURCES.md; `pnpm brand-logos` copies them to iOS and web.
├── packages/
│   ├── design-tokens/ # Design system tokens (素). Generates web CSS + iOS Swift. See docs/design/system.md.
│   ├── shared/      # Pure TS types, enums and reference tables (fuel types, brand families). No I/O.
│   ├── worker/      # Read-only Hono API + KV readers. Ingest runs from GH Actions (scripts/fetch-data.ts).
│   └── web/         # Next.js App Router. Map, hooks, station pages.
├── scripts/
│   └── fetch-data.ts  # Invoked by GH Actions cron. Calls adapters, writes KV via CF REST API.
├── docs/
│   ├── openapi.yaml   # Source of truth for the REST contract.
│   ├── design/        # Design system spec and screenshots.
│   ├── decisions/     # Decision records.
│   └── claude/*.md    # Rule docs (see below).
├── README.md          # Human entry point.
├── plan.md            # Product + roadmap narrative.
└── CLAUDE.md          # This file.
```

---

## 4. Entry points

```bash
pnpm install                                    # install all workspaces
pnpm --filter @servo-map/shared build           # shared must build before others typecheck
pnpm dev:worker                                 # wrangler dev on :8787
pnpm dev:web                                    # next dev on :3000
pnpm -r typecheck                               # repo-wide type gate
pnpm -r lint                                    # repo-wide lint gate
pnpm -r test                                    # repo-wide tests (vitest)
pnpm -r build                                   # repo-wide build
cd apps/ios && xcodegen generate                # iOS project (then xcodebuild test)
apps/ios/scripts/beta.sh                        # iOS: archive and upload to TestFlight
```

- Frontend expects `NEXT_PUBLIC_API_URL` (falls back to `http://localhost:8787` in `packages/web/src/lib/api.ts`).
- Worker expects `KV` binding + secrets — see `docs/claude/security.md`.

---

## 5. Golden rules (non-negotiable)

1. **`@servo-map/design-tokens` is the single source of truth for visual values.** Never hardcode a colour, font, radius or motion value in web or iOS; edit `src/tokens.ts` and run its `generate` script.
2. **`@servo-map/shared` is the single source of truth for types.** Never redefine `Station`, `FuelPrice`, `AustralianState`, `FuelType`, `ApiResponse` in web or worker.
3. **`docs/openapi.yaml` is the source of truth for the HTTP contract.** Update it in the same PR as any route change.
4. **Adapters follow one contract** (`packages/worker/src/adapters/types.ts` → `StateAdapter`). Add new states by copying an existing adapter — never by inventing a new pattern. See `docs/claude/adapters.md`.
5. **KV keys are namespaced in `packages/worker/src/kv/keys.ts`.** Never string-concatenate keys at call sites.
6. **No state APIs called from the browser.** The worker (or the ingest script) is the only upstream caller.
7. **Ingest is a scheduled side effect, not a request path.** A failed adapter must not fail the whole cron — use `Promise.allSettled` and preserve prior KV data.
8. **Secrets never enter the repo.** `.dev.vars`, `.env.local`, and GH secrets only. See `docs/claude/security.md`.
9. **Strict TS only.** `tsconfig.base.json` has `strict: true`; do not disable it per package.
10. **Match existing style before inventing new patterns.** Worker routes use Hono patterns; web uses App Router + hooks; types live in `shared`.
11. **Merge via squash on PR green.** Never force-push `main`. See `docs/claude/workflows.md`.

---

## 6. Rule docs

| Doc                                            | When to read                                                  |
|------------------------------------------------|---------------------------------------------------------------|
| [`docs/claude/architecture.md`](./docs/claude/architecture.md) | Understanding data flow, KV schema, package boundaries        |
| [`docs/claude/conventions.md`](./docs/claude/conventions.md)   | Before writing code — naming, file layout, TS patterns        |
| [`docs/claude/adapters.md`](./docs/claude/adapters.md) ★       | Adding a new state adapter (WA, VIC, SA, NT)                  |
| [`docs/claude/api.md`](./docs/claude/api.md)                   | Changing routes, response shape, or query params              |
| [`docs/claude/testing.md`](./docs/claude/testing.md)           | Writing tests — framework, layout, expectations               |
| [`docs/claude/deployment.md`](./docs/claude/deployment.md)     | Deploying, rolling back, env-var inventory                    |
| [`docs/claude/security.md`](./docs/claude/security.md)         | Handling secrets, tokens, rotation                            |
| [`docs/claude/workflows.md`](./docs/claude/workflows.md)       | Branch names, commit style, PR + CI flow                      |

Per-package notes: [`packages/web/CLAUDE.md`](./packages/web/CLAUDE.md) · [`packages/worker/CLAUDE.md`](./packages/worker/CLAUDE.md).

---

## 7. Out of scope for this doc

Product rationale, roadmap, and data-source tables live in [`plan.md`](./plan.md).
Do not duplicate them here — they change faster than the constitution should.
