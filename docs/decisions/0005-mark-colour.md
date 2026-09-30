# 0005 — ServoMap mark colour

- Date: 2026-09-30
- Status: **accepted** — keep the vermilion needle as a `markAccent` token
- Owner: Henry Chen

## Problem

`design/app-icon/generate.py` owned its own palette (paper `#F3EEE6`, sumi `#2A2723`, vermilion
`#C25E3A` and dark variants), so the app icon, favicon and OG images drifted from the design tokens
(`bg` is now `#F8F7F4`, `ink` `#2A2927`). The header logo already painted its needle with
`price-expensive`, so the same mark showed two different reds. The tokens had no vermilion.

## Options

| | Needle colour | Trade-off |
|---|---|---|
| A | New `markAccent` token 朱 Shu `#C25E3A` / `#D9764F` | Icon keeps its look; one non-price chroma exists, limited to the mark |
| B | Reuse `price-expensive` `#9A3B2B` / `#DE9A8A` | No new token; the logo reads as "expensive" and moves whenever the tier colour does |
| C | Reuse `ink` | Fully monochrome, closest to 墨; the favicon loses its one point of recognition |

Evidence: the committed renders in `design/app-icon/previews/` and `contact-sheet.png` (option A's
needle), and the header logo in `packages/web/src/components/shell/TopBar.tsx` (option B).

## Choice

**A**, chosen by the owner on 2026-09-30. `color.markAccent` paints the needle and pivot of the mark and
nothing else. `markColor` in `packages/design-tokens/src/tokens.ts` assigns the mark's tile (`bg`),
ink (`ink`) and accent (`markAccent`); the generator reads it through `generated/tokens.json`.

## Consequences

- The app icon and favicon tile move to `bg` and their ink to `ink`; the needle is unchanged.
- The header logo's needle moves from `price-expensive` to `mark-accent`.
- The token is not called `brand`: in this codebase a brand is a fuel brand (`brandTile`, `BrandSeal`, decision 0003).
- `MARK_COLORS` leaves the generated `mark.ts`; OG images import `markColor`.
- `python3 design/app-icon/generate.py --check` runs in CI and fails when the favicon, `mark.ts` or
  the Icon Composer bundle differ from a fresh render.
- Decision 0001's "price tiers are the only colour on screen" holds for UI; the ServoMap mark is the
  one exception.
