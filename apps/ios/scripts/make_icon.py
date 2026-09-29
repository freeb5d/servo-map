"""Draws the app icon (light, dark, tinted) from the design tokens.

Colours come from packages/design-tokens/generated/tokens.css so the icon never drifts from
the palette. Run: python3 apps/ios/scripts/make_icon.py
"""
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
CSS = (ROOT / "packages/design-tokens/generated/tokens.css").read_text()
OUT = Path(__file__).resolve().parents[1] / "Resources/Assets.xcassets/AppIcon.appiconset"
SIZE = 1024


def token(name: str, dark: bool) -> str:
    block = CSS.split(':root[data-theme="dark"]')[1] if dark else CSS.split(':root[data-theme="dark"]')[0]
    return re.search(rf"--color-{name}: (#[0-9A-Fa-f]{{6}});", block).group(1)


def draw(background, mark) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), background)
    d = ImageDraw.Draw(img)
    # The logo: an outlined square with a small solid square inside (see web Header / icon.svg).
    outer, stroke, inner = 440, 44, 150
    o0 = (SIZE - outer) // 2
    d.rounded_rectangle([o0, o0, o0 + outer, o0 + outer], radius=22, outline=mark, width=stroke)
    i0 = (SIZE - inner) // 2
    d.rectangle([i0, i0, i0 + inner, i0 + inner], fill=mark)
    return img


variants = {
    "icon-light.png": draw(token("bg", False), token("ink", False)),
    # Dark and tinted icons sit on a system-drawn background, so theirs is transparent.
    "icon-dark.png": draw((0, 0, 0, 0), token("ink", True)),
    "icon-tinted.png": draw((0, 0, 0, 0), "#FFFFFF"),
}
for name, img in variants.items():
    img.save(OUT / name)

appearances = {"icon-dark.png": "dark", "icon-tinted.png": "tinted"}
images = []
for name in variants:
    entry = {"filename": name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
    if name in appearances:
        entry["appearances"] = [{"appearance": "luminosity", "value": appearances[name]}]
    images.append(entry)
(OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
(OUT.parent / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
print("wrote", ", ".join(variants))
