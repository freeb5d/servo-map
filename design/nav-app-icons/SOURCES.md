# Navigation app icons — provenance

The icons of the apps ServoMap can hand directions to: Apple Maps, Google Maps and Waze. They are
their owners' trademarks and artwork. ServoMap shows them only in Settings › Directions, to name the
app a Directions link opens (nominative use), never as its own mark or to suggest endorsement.
Replace or remove an icon if its owner asks.

Downloaded on 30 September 2026 from the App Store lookup API
(`https://itunes.apple.com/lookup?id=915056765,585027354,323229106&country=au`), field `artworkUrl512`,
unmodified: 512 × 512 JPEG, square, without the home screen's rounded mask (the app applies it).

| File | App | App Store id | Seller | Artwork URL |
|---|---|---|---|---|
| apple.jpg | Apple Maps | 915056765 | Apple Pty Limited | https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/d7/9d/37/d79d376c-e1d6-9cb1-70fa-cdee6b6c198e/mapsCalistoga-0-0-1x_U007epad-0-1-0-85-220.png/512x512bb.jpg |
| google.jpg | Google Maps | 585027354 | Google LLC | https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/67/3d/88/673d887a-0001-c7d0-0ca2-fc8cd73a9ded/maps_2025-0-0-1x_U007epad-0-0-0-1-0-0-sRGB-0-0-85-220.png/512x512bb.jpg |
| waze.jpg | Waze Navigation & Live Traffic | 323229106 | waze | https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/55/19/94/55199472-e947-9cd1-d9d0-ceead063c7ca/AppIcon-0-0-1x_U007epad-0-1-0-85-220.png/512x512bb.jpg |

This folder is the only copy anyone edits. `pnpm nav-app-icons fetch` downloads the current artwork
again; `pnpm nav-app-icons` copies the files into
`apps/ios/Resources/Assets.xcassets/NavAppIcons`, and CI runs `pnpm nav-app-icons --check`, which fails
when that copy differs.
