import type { CircleLayer, SymbolLayer } from "react-map-gl";
import type { ExpressionSpecification, Map as MapboxMap } from "mapbox-gl";
import { color } from "@servo-map/design-tokens";
import type { Theme } from "@/lib/theme";
import { brandImage } from "./brandImages";
import { TAG_IMAGE } from "./tagImages";

// Source and layer ids, kept together so they cannot drift apart.
export const SOURCE_ID = "stations";
/** Unclustered source holding only the cheapest station (see splitCheapest). */
export const CHEAPEST_SOURCE_ID = "cheapest";
export const CLUSTER_LAYER_ID = "clusters";
export const CLUSTER_COUNT_LAYER_ID = "cluster-count";
export const CLUSTER_LABEL_LAYER_ID = "cluster-from";
export const POINT_LAYER_ID = "unclustered-point";
export const ACTIVE_LAYER_ID = "active-point";
export const CHEAPEST_LAYER_ID = "cheapest-point";

/** Cluster property holding the cheapest price inside it; give it to the source's clusterProperties. */
export const CLUSTER_PROPERTIES = { minPrice: ["min", ["get", "price"]] } as const;

const UNCLUSTERED: ExpressionSpecification = ["!", ["has", "point_count"]];
const GLYPHS = ["DIN Offc Pro Medium", "Arial Unicode MS Regular"];

/** Tier (0/1/2) to the tag image carrying that tier's colour square. */
const TIER_IMAGE: ExpressionSpecification = [
  "match",
  ["get", "tier"],
  0,
  TAG_IMAGE.cheap,
  2,
  TAG_IMAGE.pricey,
  TAG_IMAGE.fair,
];

/** Brand tile, then the price: "[logo] 225.9". */
const TAG_TEXT = ["format", brandImage("sm"), {}, " ", {}, ["get", "label"], {}] as unknown as ExpressionSpecification;

export function clusterLayer(theme: Theme): CircleLayer {
  return {
    id: CLUSTER_LAYER_ID,
    type: "circle",
    source: SOURCE_ID,
    filter: ["has", "point_count"],
    paint: {
      "circle-color": color.ink[theme],
      // The more stations, the larger the circle: 50 / 200 are the breakpoints.
      "circle-radius": ["step", ["get", "point_count"], 15, 50, 20, 200, 26],
      "circle-stroke-width": 2,
      "circle-stroke-color": color.surface[theme],
    },
  };
}

export function clusterCountLayer(theme: Theme): SymbolLayer {
  return {
    id: CLUSTER_COUNT_LAYER_ID,
    type: "symbol",
    source: SOURCE_ID,
    filter: ["has", "point_count"],
    layout: {
      "text-field": ["get", "point_count_abbreviated"],
      "text-font": GLYPHS,
      "text-size": 12,
      "text-allow-overlap": true,
    },
    paint: { "text-color": color.surface[theme] },
  };
}

/** A small paper label under each cluster: "from 229.9", the cheapest price inside it. */
export function clusterLabelLayer(theme: Theme): SymbolLayer {
  return {
    id: CLUSTER_LABEL_LAYER_ID,
    type: "symbol",
    source: SOURCE_ID,
    filter: ["has", "point_count"],
    layout: {
      "icon-image": TAG_IMAGE.plain,
      "icon-text-fit": "both",
      "icon-text-fit-padding": [1, 3, 1, 3],
      "icon-allow-overlap": true,
      "text-field": [
        "concat",
        "from ",
        ["number-format", ["get", "minPrice"], { "min-fraction-digits": 1, "max-fraction-digits": 1 }],
      ],
      "text-font": GLYPHS,
      "text-size": 11,
      "text-allow-overlap": true,
      // Clear the circle: its radius steps up with the count, so the offset does too.
      "text-offset": ["step", ["get", "point_count"], ["literal", [0, 2.5]], 50, ["literal", [0, 3.1]], 200, ["literal", [0, 3.7]]],
    },
    paint: { "text-color": color.ink[theme] },
  };
}

/**
 * Price tag for a single station: paper label, brand tile, price and a tier square. Layout properties
 * cannot read feature-state, so the selected station is excluded here and drawn by activeLayer.
 */
export function pointLayer(theme: Theme, activeId: string | null): SymbolLayer {
  return {
    id: POINT_LAYER_ID,
    type: "symbol",
    source: SOURCE_ID,
    filter: ["all", UNCLUSTERED, ["!=", ["get", "id"], activeId ?? ""]],
    layout: {
      "icon-image": TIER_IMAGE,
      "icon-text-fit": "both",
      "icon-text-fit-padding": [1, 3, 1, 3],
      "icon-allow-overlap": false,
      "text-field": TAG_TEXT,
      "text-font": GLYPHS,
      "text-size": 12,
      "text-allow-overlap": false,
      // Cheaper tags are placed first, so a collision keeps the cheap one.
      "symbol-sort-key": ["get", "price"],
    },
    paint: { "text-color": color.ink[theme] },
  };
}

/** The selected station's tag: accent fill, always drawn, above every other tag. */
export function activeLayer(theme: Theme, activeId: string | null): SymbolLayer {
  return {
    id: ACTIVE_LAYER_ID,
    type: "symbol",
    source: SOURCE_ID,
    filter: ["all", UNCLUSTERED, ["==", ["get", "id"], activeId ?? ""]],
    layout: {
      "icon-image": TAG_IMAGE.active,
      "icon-text-fit": "both",
      "icon-text-fit-padding": [1, 3, 1, 3],
      "icon-allow-overlap": true,
      "text-field": TAG_TEXT,
      "text-font": GLYPHS,
      "text-size": 12,
      "text-allow-overlap": true,
    },
    paint: { "text-color": color.onAccent[theme] },
  };
}

/**
 * The cheapest station's tag (decision 0003): larger, cheap tier fill with a halo, "Cheapest"
 * over the brand tile and price. Always drawn, and placed first so neighbouring tags give way.
 * When it is also the selected station it takes the selected fill and keeps its halo.
 */
export function cheapestLayer(theme: Theme, activeId: string | null): SymbolLayer {
  return {
    id: CHEAPEST_LAYER_ID,
    type: "symbol",
    source: CHEAPEST_SOURCE_ID,
    layout: {
      "icon-image": ["case", ["==", ["get", "id"], activeId ?? ""], TAG_IMAGE.cheapestActive, TAG_IMAGE.cheapest],
      "icon-text-fit": "both",
      "icon-text-fit-padding": [3, 6, 3, 4],
      "icon-allow-overlap": true,
      "text-field": [
        "format",
        "Cheapest",
        { "font-scale": 0.72 },
        "\n",
        {},
        brandImage("lg"),
        {},
        " ",
        {},
        ["get", "label"],
        { "font-scale": 1.3 },
      ] as unknown as ExpressionSpecification,
      "text-font": GLYPHS,
      "text-size": 13,
      "text-justify": "left",
      "text-line-height": 1.15,
      "text-allow-overlap": true,
    },
    paint: { "text-color": color.onAccent[theme] },
  };
}

export function mapStyleUrl(theme: Theme): string {
  return theme === "dark"
    ? "mapbox://styles/mapbox/dark-v11"
    : "mapbox://styles/mapbox/light-v11";
}

/**
 * Retints the base style's land and water so the map stays monochrome under the price marks.
 * Runs on every style event; the equality guard stops setPaintProperty from
 * re-triggering `styledata` in a loop.
 */
export function applyStyleOverrides(map: MapboxMap, theme: Theme): void {
  const overrides = [
    ["land", "background-color", color.mapLand[theme]],
    ["water", "fill-color", color.mapWater[theme]],
  ] as const;
  for (const [layer, prop, value] of overrides) {
    if (!map.getLayer(layer)) continue;
    if (map.getPaintProperty(layer, prop) === value) continue;
    map.setPaintProperty(layer, prop, value);
  }
}
