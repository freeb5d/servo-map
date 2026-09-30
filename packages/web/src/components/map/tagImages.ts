import type { Map as MapboxMap } from "mapbox-gl";
import { color } from "@servo-map/design-tokens";
import type { Theme } from "@/lib/theme";

/** Style image ids for the paper price tags. */
export const TAG_IMAGE = {
  cheap: "tag-cheap",
  fair: "tag-fair",
  pricey: "tag-pricey",
  active: "tag-active",
  /** Tier-less tag behind a cluster's "from" price. */
  plain: "tag-plain",
  /** The cheapest station's tag (decision 0003): cheap tier fill inside a soft halo. */
  cheapest: "tag-cheapest",
  cheapestActive: "tag-cheapest-active",
} as const;

// Drawn at 2x so the 1px hairline stays crisp on retina screens.
const RATIO = 2;
const HEIGHT = 44;
const BORDER = 2;
const RADIUS = 4;
const LEFT_CAP = 8;
const SQUARE = 10;
// Room between the text and the tier square, and between the square and the edge.
const SQUARE_GAP = 10;
const SQUARE_MARGIN = 6;
// Width of the cheapest tag's halo, and how strongly it shows.
const HALO = 8;
const HALO_ALPHA = 0.28;

interface TagStyle {
  fill: string;
  stroke: string;
  /** Tier square colour; null for a tag without one. */
  square: string | null;
  /** Soft ring drawn around the tag; the cheapest station's only. */
  halo?: string;
}

function tagStyles(theme: Theme): Record<keyof typeof TAG_IMAGE, TagStyle> {
  const surface = color.surface[theme];
  const line = color.line[theme];
  const cheap = color.priceCheap[theme];
  return {
    cheap: { fill: surface, stroke: line, square: cheap },
    fair: { fill: surface, stroke: line, square: color.priceMid[theme] },
    pricey: { fill: surface, stroke: line, square: color.priceExpensive[theme] },
    active: { fill: color.accent[theme], stroke: color.accent[theme], square: color.onAccent[theme] },
    plain: { fill: surface, stroke: line, square: null },
    cheapest: { fill: cheap, stroke: cheap, square: null, halo: cheap },
    cheapestActive: { fill: color.accent[theme], stroke: color.accent[theme], square: null, halo: cheap },
  };
}

function roundedRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

interface DrawnTag {
  image: ImageData;
  stretchX: [number, number];
  stretchY: [number, number];
  content: [number, number, number, number];
}

/**
 * Draws one stretchable tag. Only the middle stretches (icon-text-fit), so the border, the
 * corners, the halo and the tier square keep their size however long the label is.
 */
function drawTag(style: TagStyle): DrawnTag | null {
  const inset = style.halo ? HALO : 0;
  const rightCap = style.square ? SQUARE_GAP + SQUARE + SQUARE_MARGIN : LEFT_CAP;
  const width = LEFT_CAP + 16 + rightCap + inset * 2;
  const height = HEIGHT + inset * 2;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return null;

  if (style.halo) {
    roundedRect(ctx, 0, 0, width, height, RADIUS + inset);
    ctx.globalAlpha = HALO_ALPHA;
    ctx.fillStyle = style.halo;
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  roundedRect(ctx, inset + BORDER / 2, inset + BORDER / 2, width - inset * 2 - BORDER, HEIGHT - BORDER, RADIUS);
  ctx.fillStyle = style.fill;
  ctx.fill();
  ctx.lineWidth = BORDER;
  ctx.strokeStyle = style.stroke;
  ctx.stroke();

  if (style.square) {
    ctx.fillStyle = style.square;
    ctx.fillRect(width - SQUARE_MARGIN - SQUARE, (HEIGHT - SQUARE) / 2, SQUARE, SQUARE);
  }

  const left = LEFT_CAP + inset;
  const right = width - rightCap - inset;
  const bottom = height - LEFT_CAP - inset;
  return {
    image: ctx.getImageData(0, 0, width, height),
    stretchX: [left, right],
    stretchY: [left, bottom],
    content: [left, left, right, bottom],
  };
}

/**
 * Registers every tag image for the theme. Mapbox drops style images whenever the style is
 * rebuilt, so this runs on each `style.load`; existing ids are replaced to pick up a theme change.
 */
export function registerTagImages(map: MapboxMap, theme: Theme): void {
  const styles = tagStyles(theme);
  for (const key of Object.keys(TAG_IMAGE) as (keyof typeof TAG_IMAGE)[]) {
    const drawn = drawTag(styles[key]);
    if (!drawn) continue;
    const id = TAG_IMAGE[key];
    if (map.hasImage(id)) map.removeImage(id);
    map.addImage(id, drawn.image, {
      pixelRatio: RATIO,
      stretchX: [drawn.stretchX],
      stretchY: [drawn.stretchY],
      content: drawn.content,
    });
  }
}
