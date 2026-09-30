# 0003 — Brand logos and the cheapest station

- Date: 2026-09-30
- Status: **accepted** (iOS); web to follow
- Owner: Henry Chen

## Problem

Testing the iOS build, the owner could not tell at a glance which station was cheapest, and could
not recognise brands from the monochrome monogram seals of decision 0002 ("never a third-party logo").

## Options

1. Keep monogram seals, larger and clearer.
2. Monograms on tiles in each brand's colours, drawn by ServoMap. Built and shown on the simulator;
   the owner found they did not look like the brands.
3. **The brands' own logos**, on a uniform white tile, as fuel-price apps show them.
4. Redraw each brand's symbol in our style — rejected: the closer it looks, the closer it is to
   imitating the mark, with no legal advantage over the real logo and a worse result.

For the cheapest station: (a) a larger tag on the map in the cheap tier colour labelled "Cheapest",
rank numbers in the list and a tinted first row; or (b) rank numbers only.

## Choice

Option 3 and (a), chosen by the owner on 2026-09-30.

- Logos are bundled in `apps/ios/Resources/Assets.xcassets/BrandLogos`, each with its source in
  `SOURCES.md` there. They identify a station's brand (nominative use); a logo is removed if its
  owner asks.
- Brands with no usable or confirmed logo (Speedway, Astron, U-Go, Costco, Independent) keep option 2's
  monogram tile. Its colours live in `BRAND_FAMILIES[].mark` in `@servo-map/shared`, generated into
  Swift, with a WCAG AA contrast test.
- Brand colours appear only inside the brand tile. Price tiers stay the only colour carrying meaning
  elsewhere, so the rule in decision 0001 holds outside the mark.
- The web keeps its monochrome seals until it adopts the same logos.
