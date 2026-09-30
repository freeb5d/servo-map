/**
 * ServoMap design tokens — the single owner of every visual value.
 *
 * Web consumes the generated `generated/tokens.css` (Tailwind `@theme`) and imports
 * this module directly where CSS cannot reach (Mapbox paint, OG images).
 * iOS vendors the generated `generated/swift/ServoMapTokens.swift`.
 * Run `pnpm --filter @servo-map/design-tokens generate` after any change here.
 *
 * Direction: 素 — Japanese minimal. See docs/design/system.md and
 * docs/decisions/0001-japanese-minimal-design-system.md.
 */

/** A colour with one value for the light (paper) theme and one for the dark (ink) theme. */
export interface ThemeColor {
  readonly light: string;
  readonly dark: string;
}

const neutral = {
  bg: { light: "#F8F7F4", dark: "#1A1A18" },
  surface: { light: "#FDFDFB", dark: "#21211F" },
  wash: { light: "#EFEEE9", dark: "#2A2927" },
  line: { light: "#D9D6CE", dark: "#3A3935" },
  lineSubtle: { light: "#ECEAE5", dark: "#2E2D2A" },
  ink: { light: "#2A2927", dark: "#E6E3DB" },
  ink2: { light: "#5A5750", dark: "#ABA69B" },
  ink3: { light: "#6F6B63", dark: "#8F8A7F" },
} as const satisfies Record<string, ThemeColor>;

/** Every colour token. Keys are camelCase; CSS emits them kebab-cased under `--color-`. */
export const color = {
  ...neutral,
  // Variant B 墨 (decision 0001): emphasis is ink, so price tiers stay the only chroma on screen.
  accent: neutral.ink,
  accentSoft: neutral.wash,
  onAccent: neutral.surface,
  // Price tiers: 千歳緑 / 黄土 / 弁柄.
  priceCheap: { light: "#3D6848", dark: "#93B597" },
  priceMid: { light: "#85601C", dark: "#D2B271" },
  priceExpensive: { light: "#9A3B2B", dark: "#DE9A8A" },
  priceCheapSoft: { light: "#E3EAE3", dark: "#243028" },
  priceMidSoft: { light: "#EFE8DA", dark: "#312B1F" },
  priceExpensiveSoft: { light: "#F1E3DF", dark: "#34241F" },
  // The brand logo's tile (decision 0003): white in both themes, like the price sign it comes from.
  brandTile: { light: "#FFFFFF", dark: "#FFFFFF" },
  brandTileLine: { light: "#EBEBEB", dark: "#EBEBEB" },
  // A car make's mark and monogram on that tile (decision 0008): the paper theme's ink in both themes.
  brandTileInk: { light: neutral.ink.light, dark: neutral.ink.light },
  // Map base overrides applied on top of the Mapbox style.
  mapLand: { light: "#F2F1ED", dark: "#1E1E1C" },
  mapWater: { light: "#D9DFE2", dark: "#182025" },
  // 朱 Shu: the ServoMap mark's needle and nothing else (decision 0005), so price tiers stay the only UI chroma.
  markAccent: { light: "#C25E3A", dark: "#D9764F" },
  // Trends charts (decision 0008): the cheapest-to-dearest band behind an average line, between wash and line.
  chartBand: { light: "#E3E1DA", dark: "#33322F" },
  // The median marker on a price distribution, drawn in the mark's 朱 as the Trends artboards specify.
  chartMedian: { light: "#C25E3A", dark: "#D9764F" },
} as const satisfies Record<string, ThemeColor>;

export type ColorToken = keyof typeof color;

/**
 * The fuel-gauge mark's colours: app icon, favicon, header logo and OG images.
 * design/app-icon/generate.py reads them from the generated `generated/tokens.json`.
 */
export const markColor = {
  tile: color.bg,
  ink: color.ink,
  accent: color.markAccent,
} as const satisfies Record<string, ThemeColor>;

/** A font family plus the per-platform names that load it. */
export interface FontFamily {
  /** Family name as published on Google Fonts. */
  readonly family: string;
  /** Web fallback stack used before (or instead of) the loaded face. */
  readonly fallback: readonly string[];
  /**
   * On iOS, either the PostScript names of the faces the app bundles (apps/ios/scripts/fetch_fonts.sh)
   * by the web weight they stand in for, or "system" for San Francisco at the matching weight.
   */
  readonly ios: Readonly<Record<400 | 500 | 600 | 700, string>> | "system";
}

export const font = {
  display: {
    family: "Shippori Mincho",
    fallback: ["Hiragino Mincho ProN", "Yu Mincho", "Georgia", "serif"],
    ios: {
      400: "ShipporiMincho-Medium",
      500: "ShipporiMincho-Medium",
      600: "ShipporiMincho-SemiBold",
      700: "ShipporiMincho-SemiBold",
    },
  },
  body: {
    family: "Zen Kaku Gothic New",
    fallback: ["Hiragino Sans", "Yu Gothic", "system-ui", "sans-serif"],
    // The owner kept Mincho for titles and prices on iOS but found the gothic's Latin text and
    // figures odd beside the system chrome, so interface text uses San Francisco there (2026-09-29).
    ios: "system",
  },
} as const satisfies Record<string, FontFamily>;

export type FontRole = keyof typeof font;

/** SwiftUI `Font.TextStyle` a step scales with under Dynamic Type. */
export type IosTextStyle =
  | "caption2"
  | "caption"
  | "footnote"
  | "subheadline"
  | "body"
  | "title3"
  | "title2"
  | "largeTitle";

/** One step of the type scale. Sizes in px (points on iOS); tracking in em. */
export interface TextStyle {
  readonly font: FontRole;
  /** iOS scales the step with this system style so Dynamic Type keeps working. */
  readonly ios: IosTextStyle;
  readonly size: number;
  readonly lineHeight: number;
  readonly tracking: number;
  readonly weight: 400 | 500 | 600 | 700;
}

export const text = {
  label: { ios: "caption2", font: "body", size: 11, lineHeight: 1.5, tracking: 0.02, weight: 400 },
  small: { ios: "caption", font: "body", size: 12, lineHeight: 1.6, tracking: 0.02, weight: 400 },
  body: { ios: "subheadline", font: "body", size: 14, lineHeight: 1.7, tracking: 0.02, weight: 400 },
  lead: { ios: "body", font: "body", size: 16, lineHeight: 1.7, tracking: 0.02, weight: 400 },
  price: { ios: "title3", font: "display", size: 20, lineHeight: 1.2, tracking: 0, weight: 600 },
  heading: { ios: "title2", font: "display", size: 22, lineHeight: 1.35, tracking: 0.01, weight: 600 },
  display: { ios: "largeTitle", font: "display", size: 34, lineHeight: 1.3, tracking: 0.01, weight: 500 },
  priceXl: { ios: "largeTitle", font: "display", size: 48, lineHeight: 1.1, tracking: 0, weight: 600 },
} as const satisfies Record<string, TextStyle>;

/** Spacing scale in px, all multiples of 4 (余白). */
export const space = [4, 8, 12, 16, 24, 32, 48, 64] as const;

/** Corner radii in px (直線): r1 tags and pins, r2 controls, r3 panels and sheets. */
export const radius = { r1: 2, r2: 4, r3: 6 } as const;

/**
 * The 素 plain list (decision 0008), used by every list screen: rows on paper with no card around
 * the group, and a hairline only between rows, inset to the text past the row's line icon.
 * Sizes in px (points on iOS).
 */
export const list = {
  /** Left and right margin of the page. */
  gutter: space[4],
  /** Minimum height of a one-line row. */
  rowHeight: 56,
  /** Width of the rule between rows. */
  hairline: 0.5,
  /** Edge of a row's line icon; the hairline starts past the icon and `iconGap`. */
  iconSize: 24,
  iconGap: 16,
  /** Space above a group title. */
  groupGap: space[5],
} as const;

/** Motion (静): opacity plus a small translate, never scale or bounce. */
export const motion = {
  easing: [0.4, 0, 0.2, 1],
  durationMs: { fast: 150, normal: 200, slow: 300 },
  riseDistance: 4,
} as const;

/**
 * The single shadow, for chrome floating over the map. Web-only: iOS chrome uses the
 * system Liquid Glass material instead (see docs/design/system.md § Platforms).
 */
export const shadowFloat: ThemeColor = {
  light: "0 1px 2px rgb(42 41 39 / 0.06), 0 4px 16px rgb(42 41 39 / 0.06)",
  dark: "0 1px 2px rgb(0 0 0 / 0.3), 0 6px 20px rgb(0 0 0 / 0.25)",
};

/** The theme the product opens in when the viewer has no stored preference. */
export const defaultTheme: keyof ThemeColor = "light";
