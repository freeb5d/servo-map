# 0002 — Web v2 information architecture

- Date: 2026-09-29
- Status: **accepted**
- Owner: Henry Chen

## Problem

After the 素 restyle (decision 0001) the owner accepted the look but not the page logic: a full-bleed
map carried five or six floating controls, the list was an appendage of the map, map prices were bare
coloured text, brands were barely visible, filtering was brand-only, and trends were one chart at the
bottom of the SEO pages.

## Options

1. Keep the v1 layout and restyle only (rejected by the owner after seeing it running).
2. **v2: verdict first, ledger list, map answers "where"** — evidence:
   [`docs/design/web-v2.html`](../design/web-v2.html) (desktop and phone plates, brand, filter and trends systems).

## Choice

Option 2, approved 2026-09-29, with the iOS design updated to match
([`docs/design/ios-27.html`](../design/ios-27.html)).

- Three sections on every platform: Map (`/`), Trends (`/trends`), Saved (`/saved`).
  A fixed paper top bar on desktop; a bottom tab bar on phones.
- The map page opens with a verdict (cheapest nearby, cycle position), then quick filters,
  then a price-ranked ledger; the map sits to the right. Station detail is a right-hand drawer
  (full-height sheet on phones) and never replaces the list.
- Every station shows a brand seal. Raw upstream brand names resolve to brand families through
  `BRAND_FAMILIES` in `@servo-map/shared`, the single table for web, iOS and ingest.
- Filters: quick chips plus a panel (price ceiling with distribution, distance, freshness,
  brand families with include/exclude, "also sells"). Filter state lives in the URL.
- Trends: verdict, cycle position, averages, local spread, 120-day chart with honest data gaps,
  all-fuel comparison, brand and suburb rankings, weekday pattern, savings calculator.

## Consequences

- `Header`, the floating `SearchBar`, `LocationPrime` and the floating freshness badge are removed.
- State-wide brand and suburb rankings are computed in the browser from `/stations` for now;
  moving them into the ingest cron is the follow-up if payloads grow.
- Opening hours, car wash and discount dockets are not filters until the API carries that data.
