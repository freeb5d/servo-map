import type { PriceSnapshot } from "@servo-map/shared";
import { dayNumber, splitAtGaps } from "@/lib/trends";

interface SparklineProps {
  /** One fuel's ascending snapshots. */
  snapshots: PriceSnapshot[];
  width?: number;
  height?: number;
}

/** A word-sized trend line; like the full chart it breaks where days are missing. */
export function Sparkline({ snapshots, width = 80, height = 20 }: SparklineProps) {
  if (snapshots.length < 2) return <span className="text-ink-3">&mdash;</span>;
  const avgs = snapshots.map((s) => s.avg);
  const lo = Math.min(...avgs);
  const span = Math.max(...avgs) - lo || 1;
  const day0 = dayNumber(snapshots[0].date);
  const daySpan = dayNumber(snapshots[snapshots.length - 1].date) - day0 || 1;
  const x = (s: PriceSnapshot): number => ((dayNumber(s.date) - day0) / daySpan) * width;
  const y = (s: PriceSnapshot): number => height - 2 - ((s.avg - lo) / span) * (height - 4);

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden="true" className="block">
      {splitAtGaps(snapshots)
        .filter((run) => run.length > 1)
        .map((run) => (
          <polyline
            key={run[0].date}
            points={run.map((s) => `${x(s)},${y(s)}`).join(" ")}
            fill="none"
            strokeWidth="1.2"
            className="stroke-ink-2"
          />
        ))}
    </svg>
  );
}
