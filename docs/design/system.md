# ServoMap design system — 素 (Su)

> Status: **accepted — variant B 墨 Sumi** (see [decision 0001](../decisions/0001-japanese-minimal-design-system.md)).
> Token source: [`packages/design-tokens/src/tokens.ts`](../../packages/design-tokens/src/tokens.ts).
> Visual evidence: [`specimen.html`](./specimen.html) (web) · [`ios-27.html`](./ios-27.html) (iOS 27).

Japanese minimal, quiet, restrained. A muted map on washi paper, sumi ink for text and emphasis,
and muted price tiers. Price is the only colour that should draw the eye.

## Principles

| | Principle | Rule |
|---|---|---|
| 余白 | Ma — space | Group with space, not boxes. Spacing is a multiple of 4; panel padding starts at 16. |
| 素材 | Material | Surfaces are flat paper. 1px hairlines separate. No glassmorphism. Only elements floating over the map get the single shadow. |
| 抑制 | Restraint | One accent. Colour must carry meaning: price tier, freshness, selection. |
| 直線 | Line | Radii 2 / 4 / 6px, no pills. Marks are small squares ■. Icons are 1.5px stroke, square caps. |
| 静 | Stillness | Motion is opacity plus ≤ 4px translate at 200ms. No scale, no bounce, no shimmer. |

## Colour tokens

Every value below passes WCAG AA (≥ 4.5:1) for text on `bg` and `surface` in its theme.
`ink-3` on `wash` measures 4.2–4.3:1, so never set small `ink-3` text on `wash`.

| Token | Light 紙 | Dark 墨 | Use |
|---|---|---|---|
| `bg` | `#F8F7F4` | `#1A1A18` | Page and map frame |
| `surface` | `#FDFDFB` | `#21211F` | Panels, inputs, pins |
| `wash` | `#EFEEE9` | `#2A2927` | Hover, pressed, skeleton |
| `line` | `#D9D6CE` | `#3A3935` | Borders |
| `line-subtle` | `#ECEAE5` | `#2E2D2A` | Row dividers |
| `ink` | `#2A2927` | `#E6E3DB` | Primary text |
| `ink-2` | `#5A5750` | `#ABA69B` | Secondary text |
| `ink-3` | `#6F6B63` | `#8F8A7F` | Captions, units |
| `accent` = `ink` | `#2A2927` | `#E6E3DB` | Primary button, selection, user location, trend line |
| `accent-soft` = `wash` | `#EFEEE9` | `#2A2927` | Selected row |
| `on-accent` = `surface` | `#FDFDFB` | `#21211F` | Text on accent |
| `price-cheap` 千歳緑 | `#3D6848` | `#93B597` | Cheapest third |
| `price-mid` 黄土 | `#85601C` | `#D2B271` | Middle third |
| `price-expensive` 弁柄 | `#9A3B2B` | `#DE9A8A` | Top third |
| `*-soft` tiers | `#E3EAE3` / `#EFE8DA` / `#F1E3DF` | `#243028` / `#312B1F` / `#34241F` | Banner fills |
| `map-land` / `map-water` | `#F2F1ED` / `#D9DFE2` | `#1E1E1C` / `#182025` | Web map base overrides |

Variant A 藍 (indigo accent) was the alternative; it was not chosen.

A price tier always shows its word (Cheap, Fair, Pricey) in the tier colour (WCAG 1.4.1). The ■ mark appears only where there is no room for the word: map tags and the map legend.

## Typography

| Role | Face | Size / line-height | Notes |
|---|---|---|---|
| Price XL | Shippori Mincho 600 | 48 / 1.1 | Station detail headline price |
| Display | Shippori Mincho 500 | 34 / 1.3 | SEO page H1 |
| Heading | Shippori Mincho 600 | 22 / 1.35 | Station name, section titles |
| Price row | Shippori Mincho 600 | 20 / 1.2 | Lists; `tabular-nums` |
| Body | Zen Kaku Gothic New 400 | 14 / 1.7, +0.02em | All UI copy |
| Small | Zen Kaku Gothic New 400 | 12 / 1.6 | Addresses, timestamps |
| Label | Zen Kaku Gothic New 400 | 11 / 1.5 | Captions on dense chrome; sentence case, never letter-spaced capitals |

On the web both faces load through `next/font/google` with the `latin` subset; they replace Syne and DM Sans.

On iOS, Shippori Mincho is bundled for titles and prices, and interface text uses San Francisco at the same weights (the gothic's Latin text and figures sat oddly beside the system chrome). The generated `ServoMapFont` does this from the token, so the Body, Small and Label rows follow Dynamic Type through the system text styles.

## Voice and restraint

Rules added after the owner found the first v2 build "too AI" (2026-09-29). They apply to web and iOS.

- **No letter-spaced capitals.** Section names, table heads and captions are sentence case in `caption` (small, `ink-3`). Brand monograms are the only capitals, because they are marks.
- **No card soup.** Modules on a page are separated by space and one `line` hairline, not boxed. Boxes are for things you act on (inputs, buttons, floating chrome), not for groups of text.
- **No KPI tile rows.** Headline figures sit unboxed in a ruled row, like a newspaper table.
- **Facts, not advice.** Verdicts state where the price is ("Near the 90-day high.", "10.6¢ below the local average"), never what the reader should do.
- **No explaining the chart.** If a chart needs a caption to be honest (a bar axis that does not start at zero), change the chart: use dots on a scale or a row of figures.
- **No decorative colour.** No gradients; the cycle position is a hairline with one ink tick. Colour marks price tier, freshness and selection only.
- **Fewer separators.** Use a comma or space; `·` chains are out.

## Space, shape, elevation

- Spacing scale: 4, 8, 12, 16, 24, 32, 48, 64.
- Radii: `r-1` 2px (tags, chips, pins), `r-2` 4px (buttons, inputs, segmented control), `r-3` 6px (panels, sheets).
- One shadow, `shadow-float`, only for chrome floating over the map. Panels docked to an edge use a hairline instead.

## Components

| Component | Replaces | Shape |
|---|---|---|
| FuelSwitch | pill toggle in `Header` | 1px-bordered segmented control, `r-2`, selected item filled `accent` |
| Button | ochre pill buttons | primary (accent fill), secondary (surface + line), quiet (text, underline on hover); 40px, 30px `sm` |
| SearchField | glass search bar | surface, 1px line, focus turns the border `accent` |
| FilterChip | ochre pill chip | surface, 1px line, `r-1`, 26px |
| Freshness | coloured pill | neutral tag with a 6px tier square |
| StaleBanner | glass banner | `price-mid-soft` fill, no border |
| Ledger row | `StationCard` rounded card | rank, brand mark, name + suburb · distance, price + tier; hairline divider; selected = `accent-soft`; rows older than 24 h sit below a separator. The cheapest ranked row sits on `price-cheap-soft` with its rank in semibold `price-cheap` (decision 0003) |
| Map dot (iOS) | — | filled tier colour for a current price; hollow ink-3 ring for a price more than a week old, which shows on the map and its page but is not ranked or quoted as cheapest |
| Verdict | list header "Nearby Stations" | "Cheapest {fuel} near {place}" in semibold `price-cheap`, cheapest price, one-sentence cycle verdict in Mincho, cycle bar |
| PriceTag | Syne bold + coloured number | Mincho number in `ink`, tier shown by label + ■ in tier colour |
| BrandSeal | brand as small ochre text | Decision 0003, both platforms: the brand's logo on a `brand-tile` square (corner 24 % of its edge, 0.5px `brand-tile-line`), or, where no logo is bundled, the family monogram on a tile in `BRAND_FAMILIES[].mark` colours (`@servo-map/shared`) with the optional stripe along the bottom; members-only brands get a dashed `ink-3` ring. Web sizes 22 / 30 / 36px (inline and short lists / ledger / station header). Logos live once in `design/brand-logos` (see its `SOURCES.md`); `pnpm brand-logos` copies them into the iOS asset catalog and `packages/web/public/brand-logos`, and CI fails when a copy drifts |
| Cheapest tag | — | the cheapest ranked station's map tag: larger, `price-cheap` fill with a `price-cheap` halo, "Cheapest" over the brand mark and price, text in `on-accent`; selected, it fills `accent` and keeps the halo. iOS breathes the halo by opacity; the web halo is still, so the map costs no work while idle. On the web it has its own unclustered source, so it shows at every zoom |
| Map tag | bare coloured price text | paper tag: brand mark (16px), Mincho price, tier square; selected tag inverts to `accent`; clusters show "from {min}" |
| Cluster | ochre circle | `ink` circle, count in `surface` |

## Map

- Web: Mapbox `light-v11` / `dark-v11`, with the `land` and `water` layers repainted from
  `map-land` / `map-water` at load. Mapbox Standard's monochrome theme is a later option.
- iOS: MapKit `.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll)`.

## Motion

- Enter: fade + 4px rise, 200ms, `cubic-bezier(0.4, 0, 0.2, 1)`.
- Hover and press: background colour only.
- Loading: static `wash` blocks with a slow opacity breathe; no shimmer gradient.
- `prefers-reduced-motion`: all motion off.

## Platforms

| Layer | Web | iOS 27 |
|---|---|---|
| Content (lists, prices, charts) | 素 paper, hairlines | 素 paper, hairlines, Dynamic Type |
| Chrome (bars, controls, sheets) | Flat `surface` + `line`, one `shadow-float` over the map | System Liquid Glass: `glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent` |
| Shape | 2 / 4 / 6px everywhere | 2 / 4 / 6pt content; capsules and concentric corners come from the system chrome |
| Emphasis | `accent` fill | `accent` as glass tint only |

## Single source of truth

- `packages/design-tokens/src/tokens.ts` owns every value.
- `pnpm --filter @servo-map/design-tokens generate` writes `generated/tokens.css` (imported by
  `packages/web/src/app/globals.css`) and `generated/swift/ServoMapTokens.swift` (vendored into the iOS app).
- A vitest drift check fails when either generated file differs from `tokens.ts`; another checks
  WCAG AA contrast for every text colour in both themes.
- TypeScript that cannot read CSS (Mapbox paint, OG images) imports `@servo-map/design-tokens` directly.

## Rollout order

1. Tokens package; tokens and fonts in `globals.css` and `layout.tsx`; rename `ochre` → `accent`, drop `terracotta` and `.glass*`.
2. Primitives: PriceTag, FuelSwitch, Button, SearchField, FilterChip, Freshness, StaleBanner.
3. Map: Standard monochrome style, pins, clusters, user location.
4. Surfaces: StationRow list, StationDetail, BottomSheet, desktop panel.
5. Pages: `/fuel/[state]`, `/fuel/[state]/[suburb]`, `/station/[id]`, `/about`, OG images, favicon.
6. iOS app: vendor `ServoMapTokens.swift`, bundle Shippori Mincho, build the tabs in [`ios-27.html`](./ios-27.html).
