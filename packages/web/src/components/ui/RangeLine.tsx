import { formatPriceCents } from "@/lib/utils";

interface RangeLineProps {
  min: number;
  max: number;
  current: number;
  /** Window length, for the accessible description. */
  days: number;
}

/** Today's average on a hairline between the window's low and high, marked by a single tick. */
export function RangeLine({ min, max, current, days }: RangeLineProps) {
  const ratio = max > min ? (current - min) / (max - min) : 0.5;
  const pct = Math.min(1, Math.max(0, ratio)) * 100;
  return (
    <div className="grid gap-1.5">
      <div
        role="img"
        aria-label={`Average ${formatPriceCents(current)}, between the ${days}-day low of ${formatPriceCents(min)} and high of ${formatPriceCents(max)}`}
        className="relative h-px bg-line"
      >
        <span aria-hidden="true" className="absolute -top-1 h-[9px] w-px bg-ink" style={{ left: `${pct}%` }} />
      </div>
      <div className="flex justify-between text-small text-ink-3 tabular-nums">
        <span>{formatPriceCents(min)}</span>
        <span>{formatPriceCents(max)}</span>
      </div>
    </div>
  );
}
