import type { ReactNode } from "react";

export type IconName =
  | "search"
  | "locate"
  | "close"
  | "bookmark"
  | "share"
  | "directions"
  | "filter"
  | "check"
  | "warning"
  | "sun"
  | "moon"
  | "arrow-left"
  | "arrow-right"
  | "pin"
  | "map"
  | "trend";

// All glyphs share a 24px grid and are drawn as strokes so the 1.5px square-cap
// look stays consistent; only `bookmark` may be filled.
const PATHS: Record<IconName, ReactNode> = {
  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="M16 16l5 5" />
    </>
  ),
  locate: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v4M12 18v4M2 12h4M18 12h4" />
    </>
  ),
  close: <path d="M6 6l12 12M18 6L6 18" />,
  bookmark: <path d="M6 3h12v18l-6-4.5L6 21z" />,
  share: <path d="M12 15V3M7 8l5-5 5 5M5 14v7h14v-7" />,
  directions: <path d="M3 11l18-8-8 18-2-8z" />,
  filter: <path d="M3 6h18M6 12h12M10 18h4" />,
  check: <path d="M4 12l5 5L20 6" />,
  warning: (
    <>
      <path d="M12 3l10 18H2z" />
      <path d="M12 10v5M12 18h.01" />
    </>
  ),
  sun: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2" />
    </>
  ),
  moon: <path d="M20 14.5A8 8 0 1 1 9.5 4 6.5 6.5 0 0 0 20 14.5z" />,
  "arrow-left": <path d="M20 12H4M10 6l-6 6 6 6" />,
  "arrow-right": <path d="M4 12h16M14 6l6 6-6 6" />,
  map: <path d="M9 4L3 6v14l6-2 6 2 6-2V4l-6 2-6-2zM9 4v14M15 6v14" />,
  trend: <path d="M3 17l6-6 4 4 8-8M15 7h6v6" />,
  pin: (
    <>
      <path d="M12 22s7-6.5 7-12a7 7 0 1 0-14 0c0 5.5 7 12 7 12z" />
      <circle cx="12" cy="10" r="2.5" />
    </>
  ),
};

interface IconProps {
  name: IconName;
  size?: number;
  className?: string;
  /** Solid fill; meaningful for `bookmark` (saved state). */
  filled?: boolean;
}

/** Single icon set for the app: 1.5px stroke, square caps, mitered joins (直線). */
export function Icon({ name, size = 16, className, filled = false }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={filled ? "currentColor" : "none"}
      stroke="currentColor"
      strokeWidth={1.5}
      strokeLinecap="square"
      strokeLinejoin="miter"
      aria-hidden="true"
      className={className}
    >
      {PATHS[name]}
    </svg>
  );
}
