# 0001 — Japanese minimal design system

- Date: 2026-09-29
- Status: **accepted** — variant B 墨 Sumi
- Owner: Henry Chen

## Problem

The current UI is dark-first with glassmorphism, pill controls, Syne display type, an ochre/terracotta
accent, and saturated green/amber/red price colours. The owner wants to drop that style entirely for a
Japanese, minimal, quiet (日系 · 简约 · 素雅) look, starting from a design system. The product is
moving to two platforms, web and iOS, and the iOS app must follow the iOS 27 Liquid Glass standard.

## Options

Both options share neutrals, typography (Shippori Mincho + Zen Kaku Gothic New), spacing, radii,
motion, and the muted price tiers. They differ only in the accent. Evidence: the interactive
specimen at [`docs/design/specimen.html`](../design/specimen.html), which renders both variants in
light and dark, every primitive, a desktop map screen, and two phone screens.

| | A · 藍 Ai | B · 墨 Sumi |
|---|---|---|
| Accent | Indigo `#2F4F6B` / `#9DB4C8` | Ink (no chromatic accent) |
| Selected station | Clearly distinct from price colours | Distinguished by value only |
| Feel | Quiet, warm paper with one cool note | Print-like, most austere |
| Risk | Slightly more colour on screen | Weaker selection state in dark mode |

Keeping the current style was ruled out by the owner.

## Choice

**B · 墨 Sumi**, chosen by the owner on 2026-09-29. Price tiers are the only colour on screen.

Because the product targets web and iOS, the tokens live in a platform-neutral package,
`packages/design-tokens`, which generates the web CSS and the iOS Swift file.

On iOS, the design system splits into two layers:

- **Chrome follows iOS 27 Liquid Glass.** Tab bar, search tab, toolbars, map controls, the tab
  bottom accessory and partial-detent sheets use the system glass material
  (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent` button styles).
  ServoMap does not draw its own blur or shadow there.
- **Content stays 素.** Lists, prices, tables and charts sit on the paper surface with hairlines,
  Mincho numerals, and the muted price tiers, all from the generated Swift tokens, with Dynamic Type.

The web keeps flat paper chrome with no glass. iOS design evidence:
[`docs/design/ios-27.html`](../design/ios-27.html).

## Consequences

- Default web theme moves from dark to the system preference, falling back to light (paper).
- `ochre`/`terracotta` tokens and `.glass*` utilities are removed from the web; `accent` = ink.
- Price-tier hex duplicated in `src/lib/utils.ts` and `MapView.tsx` is replaced by imports from
  `@servo-map/design-tokens`.
- The iOS app uses MapKit with the muted standard style instead of Mapbox.
- New iOS features (price alerts, route mode) need new backend endpoints; they are proposals until
  a separate decision schedules them.
