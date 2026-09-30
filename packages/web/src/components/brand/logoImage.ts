import { brandLogoSrc } from "./logos";

/** Pixel width fetched for every logo: a tile shows it at 29 CSS px at most, so 64 covers 2x. */
export const LOGO_FETCH_WIDTH = 64;

/**
 * URL of the family's logo resized by the Next image optimiser (the default loader's
 * `/_next/image` route), or null when the family draws its monogram tile. Built by hand rather
 * than through next/image, which adds about 6 kB of script to every page that shows a brand.
 */
export function brandLogoImage(familyId: string): string | null {
  const src = brandLogoSrc(familyId);
  return src ? `/_next/image?url=${encodeURIComponent(src)}&w=${LOGO_FETCH_WIDTH}&q=75` : null;
}
