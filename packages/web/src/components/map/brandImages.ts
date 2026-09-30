import type { ExpressionSpecification, Map as MapboxMap } from "mapbox-gl";
import { BRAND_FAMILIES, type BrandFamily } from "@servo-map/shared";
import { color } from "@servo-map/design-tokens";
import { BRAND_LOGO_IDS, brandLogoSrc } from "@/components/brand/logos";
import { brandLogoImage } from "@/components/brand/logoImage";

/** Tile edge in CSS px: on a station's tag, and on the cheapest station's larger tag. */
export const BRAND_IMAGE_SIZE = { sm: 16, lg: 22 } as const;
type Size = keyof typeof BRAND_IMAGE_SIZE;

// Drawn at 2x so logos stay sharp on retina screens.
const RATIO = 2;

const imageId = (size: Size, familyId: string) => `brand-${size}-${familyId}`;

/** The feature's brand tile as a `format` section; features carry their family id in `family`. */
export function brandImage(size: Size): ExpressionSpecification {
  return ["image", ["concat", `brand-${size}-`, ["get", "family"]]];
}

/** Logos by family id once loaded; null for one that failed, which keeps a plain white tile. */
const logos = new Map<string, HTMLImageElement | null>();
let preload: Promise<void> | null = null;

function loadLogo(familyId: string, src: string): Promise<void> {
  const img = new Image();
  img.src = src;
  return img.decode().then(
    () => void logos.set(familyId, img),
    (error: unknown) => {
      console.warn(`Brand logo ${src} did not load`, error);
      logos.set(familyId, null);
    },
  );
}

/**
 * Loads every logo and the body font before the tags are drawn. Mapbox lays out a tag's text
 * with the image it has at that moment and does not redraw it, so tiles must be complete up front.
 */
export function preloadBrandImages(): Promise<void> {
  preload ??= Promise.all([
    ...[...BRAND_LOGO_IDS].map((id) => loadLogo(id, brandLogoImage(id) as string)),
    document.fonts.ready,
  ]).then(() => undefined);
  return preload;
}

/** The body font stack the page loaded (tokens' `--font-body`), for monograms. */
function bodyFont(): string {
  return getComputedStyle(document.documentElement).getPropertyValue("--font-body").trim() || "sans-serif";
}

/**
 * Draws the same tile as BrandSeal: the logo on white where one is bundled, otherwise the
 * monogram on the brand's colours with an optional stripe.
 */
function drawTile(family: BrandFamily, size: Size): ImageData | null {
  const px = BRAND_IMAGE_SIZE[size] * RATIO;
  const canvas = document.createElement("canvas");
  canvas.width = px;
  canvas.height = px;
  const ctx = canvas.getContext("2d");
  if (!ctx) return null;
  ctx.beginPath();
  ctx.roundRect(0, 0, px, px, px * 0.24);
  ctx.clip();

  if (brandLogoSrc(family.id)) {
    ctx.fillStyle = color.brandTile.light;
    ctx.fillRect(0, 0, px, px);
    const logo = logos.get(family.id);
    if (logo) ctx.drawImage(logo, px * 0.1, px * 0.1, px * 0.8, px * 0.8);
    // Stroked on the clip path, so only its inner half shows: a hairline like BrandSeal's.
    ctx.strokeStyle = color.brandTileLine.light;
    ctx.lineWidth = RATIO;
    ctx.stroke();
  } else {
    const { background, foreground, stripe } = family.mark;
    ctx.fillStyle = background;
    ctx.fillRect(0, 0, px, px);
    if (stripe) {
      ctx.fillStyle = stripe;
      ctx.fillRect(0, px * 0.86, px, px * 0.14);
    }
    ctx.fillStyle = foreground;
    ctx.font = `700 ${Math.round(px * (family.seal.length > 2 ? 0.3 : 0.38))}px ${bodyFont()}`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(family.seal, px / 2, px * 0.47, px * 0.9);
  }
  return ctx.getImageData(0, 0, px, px);
}

/**
 * Registers every family's tile at both sizes. Like the tag images, these are dropped whenever
 * Mapbox rebuilds the style, so this runs on each `style.load`.
 */
export function registerBrandImages(map: MapboxMap): void {
  for (const family of BRAND_FAMILIES) {
    for (const size of Object.keys(BRAND_IMAGE_SIZE) as Size[]) {
      const drawn = drawTile(family, size);
      if (!drawn) continue;
      const id = imageId(size, family.id);
      if (map.hasImage(id)) map.removeImage(id);
      map.addImage(id, drawn, { pixelRatio: RATIO });
    }
  }
}
