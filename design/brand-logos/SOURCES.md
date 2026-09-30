# Brand logos — provenance

Trademarks of their owners, used to identify each station's brand (nominative use), as fuel-price
apps do. Retrieved 30 September 2026 and normalised to a 256 px square with a transparent margin.
Replace or remove a logo if its owner asks. Brands without a file here draw their monogram tile
(`BrandSeal` in `apps/ios/Sources/Components.swift` and `packages/web/src/components/ui/BrandSeal.tsx`).

Each file is named by its `BRAND_FAMILIES` id (`packages/shared/src/brands.ts`). This folder is the
only copy anyone edits: after adding, replacing or removing a file, run `pnpm brand-logos` from the
repository root to regenerate the iOS asset catalog and the web's static copies, and commit them.

| File | Source |
|---|---|
| shell.png | https://www.shell.com.au/etc.clientlibs/amidala/clientlibs/theme-base/resources/favicon/apple-touch-icon.png |
| caltex.png | https://www.caltex.com/etc/designs/caltex/favicon/android-icon-192x192.png |
| metro.png | https://metropetroleum.com.au/wp-content/uploads/2020/05/cropped-metro-petroleum-1-192x192.png |
| united.png | Site icon of unitedpetroleum.com.au (via Google favicon service, 120 px) |
| liberty.png | https://www.libertyoil.com.au/favicon.ico |
| puma.png | https://pumaenergy.com/wp-content/uploads/2023/10/cropped-puma-favicon-192x192.jpeg |
| 7-eleven.png | Site icon of 7eleven.com.au (via Google favicon service, 256 px) |
| mobil.png | Site icon of mobil.com.au (via Google favicon service, 144 px) |
| bp.png | https://en.wikipedia.org/wiki/File:BP_Helios_logo.svg (non-free logo) |
| ampol.png | https://en.wikipedia.org/wiki/File:Ampol_Logo_May_2020.svg (non-free logo) |

Not found at a usable size or not confirmed as the fuel brand's mark: Speedway, Astron, U-Go,
Costco. They keep the monogram tile.
