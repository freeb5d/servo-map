# Car make marks — provenance

Vendored unchanged from the npm package [`simple-icons`](https://www.npmjs.com/package/simple-icons)
**16.33.0** (`icons/{slug}.svg`), retrieved 30 September 2026. Simple Icons releases its SVG files
under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/); none of the files below carries
a per-icon licence in the package's `data/simple-icons.json`. The marks themselves remain
trademarks of their owners and are used only to identify the make of the user's car (nominative
use, decision 0008). Replace or remove a mark if its owner asks, and read the brand guidelines
linked below before changing how a mark is drawn.

Each file is named by `makeSlug(make)` from `@servo-map/shared` (`packages/shared/src/vehicles.ts`)
for a make in the car catalogue. This folder is the only copy anyone edits: after adding, replacing
or removing a file, run `pnpm car-logos` from the repository root to regenerate the iOS asset
catalog (`apps/ios/Resources/CarLogos.xcassets`), and commit it. CI runs `pnpm car-logos --check`
and fails when the copy drifts.

The apps draw each mark in `brand-tile-ink` on a white 1:1 `brand-tile` (`CarMark` in
`apps/ios/Sources/CarMark.swift`).

| File | Simple Icons slug | Title | Source recorded by Simple Icons | Guidelines |
|---|---|---|---|---|
| audi.svg | audi | Audi | https://www.audi.com/ci/en/intro/basics/rings.html | https://www.audi.com/ci/en/intro/basics/rings.html |
| bmw.svg | bmw | BMW | https://bmw.com | |
| ford.svg | ford | Ford | https://secure.ford.com/brochures/ | |
| honda.svg | honda | Honda | https://www.honda.ie | |
| hyundai.svg | hyundai | Hyundai | https://www.hyundai.com | |
| jeep.svg | jeep | Jeep | https://commons.wikimedia.org/wiki/File:Jeep_logo.svg | |
| kia.svg | kia | Kia | https://www.kia.com | |
| mazda.svg | mazda | Mazda | https://www.mazda.com/en/about/profile/library/ | |
| mg.svg | mg | MG | https://www.mg.co.uk/themes/custom/mg/assets/images/svg/mg-logo-desktop.svg | https://www.mg.co.uk/terms-and-conditions |
| mitsubishi.svg | mitsubishi | Mitsubishi | https://www.mitsubishi.com | |
| nissan.svg | nissan | Nissan | https://www.nissan.ie | |
| renault.svg | renault | Renault | https://media.renaultgroup.com | |
| skoda.svg | skoda | ŠKODA | https://www.skoda-connect.com | |
| subaru.svg | subaru | Subaru | https://commons.wikimedia.org/wiki/File:Subaru_logo.svg | |
| suzuki.svg | suzuki | Suzuki | https://www.suzuki.ie | |
| toyota.svg | toyota | Toyota | https://www.toyota.com/brandguidelines/logo/ | https://www.toyota.com/brandguidelines/ |
| volkswagen.svg | volkswagen | Volkswagen | https://www.vw.com | |

Not in Simple Icons 16.33.0: BYD, GWM, Holden, Isuzu, Land Rover, LDV, Lexus, Mercedes-Benz. They
keep a monogram tile, as brands without a logo do in decision 0003.
