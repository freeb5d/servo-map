#!/usr/bin/env bash
# Vendors the display face the web uses (see packages/design-tokens/src/tokens.ts `font`) into the app.
# Interface text on iOS is the system font, so only Shippori Mincho is bundled.
# Source: github.com/google/fonts (SIL Open Font License 1.1, licence files kept alongside).
# The UI is English, so each face is subset to Latin plus the few symbols the app prints,
# which takes the bundle from about 23 MB to about 230 KB. Needs `uvx` (for fontTools).
set -euo pipefail
cd "$(dirname "$0")/../Resources/Fonts"
base=https://raw.githubusercontent.com/google/fonts/main/ofl
for f in shipporimincho/ShipporiMincho-Medium.ttf shipporimincho/ShipporiMincho-SemiBold.ttf; do
  name=$(basename "$f")
  curl -sSfL -o "$name" "$base/$f"
  uvx --from fonttools pyftsubset "$name" --layout-features='*' --output-file="$name.sub" \
    --unicodes="U+0020-007E,U+00A0-00FF,U+2010-2027,U+2030-203A,U+2190-2193,U+25B2,U+25BC,U+2212"
  mv "$name.sub" "$name"
done
curl -sSfL -o OFL-ShipporiMincho.txt "$base/shipporimincho/OFL.txt"
