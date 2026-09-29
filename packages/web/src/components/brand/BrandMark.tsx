import {
  MARK_DROP,
  MARK_NEEDLE,
  MARK_PIVOT,
  MARK_TICKS,
  MARK_TILE_RADIUS,
  MARK_TRANSFORM,
  MARK_VIEWBOX,
} from "./mark";

interface BrandMarkProps {
  /** Rendered width and height in pixels. */
  size: number;
  /** Tile, ink and accent colours; any CSS colour, including `var(--token)`. */
  tile: string;
  ink: string;
  accent: string;
}

/**
 * The ServoMap fuel-gauge mark on its rounded tile.
 * Geometry comes from the generated `mark.ts`, shared with the favicon and the iOS app icon.
 */
export function BrandMark({ size, tile, ink, accent }: BrandMarkProps) {
  return (
    <svg width={size} height={size} viewBox={MARK_VIEWBOX} aria-hidden="true">
      <rect width="1024" height="1024" rx={MARK_TILE_RADIUS} fill={tile} />
      <g transform={MARK_TRANSFORM}>
        {MARK_TICKS.map((tick) => (
          <path
            key={tick.width}
            d={tick.d}
            fill="none"
            stroke={ink}
            strokeWidth={tick.width}
            strokeLinecap="round"
          />
        ))}
        <path d={MARK_DROP} fill={ink} />
        <path
          d={MARK_NEEDLE.d}
          fill="none"
          stroke={accent}
          strokeWidth={MARK_NEEDLE.width}
          strokeLinecap="round"
        />
        <circle cx={MARK_PIVOT.cx} cy={MARK_PIVOT.cy} r={MARK_PIVOT.r} fill={accent} />
      </g>
    </svg>
  );
}
