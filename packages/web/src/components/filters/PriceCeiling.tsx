"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { priceHistogram } from "@/lib/aggregate";
import { formatPriceCents } from "@/lib/utils";

interface PriceCeilingProps {
  fuel: string;
  /** Prices of every station the other filters leave in, so the shape does not shrink as the ceiling drops. */
  prices: number[];
  /** Current ceiling; undefined means no limit. */
  value: number | undefined;
  average: number | null;
  onChange: (max: number | undefined) => void;
}

const COMMIT_DELAY_MS = 150;

/** Price distribution with a ceiling slider: thin bars, ink up to the ceiling, hairline grey past it. */
export function PriceCeiling({ fuel, prices, value, average, onChange }: PriceCeilingProps) {
  const bins = useMemo(() => priceHistogram(prices, 28), [prices]);
  const [draft, setDraft] = useState<number | null>(null);
  const timer = useRef<number | undefined>(undefined);
  useEffect(() => () => window.clearTimeout(timer.current), []);

  if (bins.length === 0) return null;
  const lo = bins[0].from;
  const hi = bins[bins.length - 1].to;
  if (hi <= lo) return null;

  const ceiling = draft ?? value ?? hi;
  const pct = Math.min(100, Math.max(0, ((ceiling - lo) / (hi - lo)) * 100));
  const maxCount = Math.max(...bins.map((b) => b.count));

  // Sliding writes to the URL, so wait for the thumb to settle instead of replacing on every pixel.
  const move = (next: number) => {
    setDraft(next);
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      onChange(next >= hi ? undefined : next);
      setDraft(null);
    }, COMMIT_DELAY_MS);
  };

  return (
    <div className="grid gap-2 border-b border-line-subtle py-3">
      <div className="flex items-baseline justify-between">
        <span className="caption">Max price, {fuel}</span>
        <span className="font-display text-[15px] font-semibold tabular-nums text-ink">
          {ceiling >= hi ? "Any" : `≤ ${formatPriceCents(ceiling)}`}
        </span>
      </div>

      <div aria-hidden="true" className="flex h-[52px] items-end">
        {bins.map((bin, i) => (
          <div key={i} className="flex h-full flex-1 items-end justify-center">
            {/* Empty buckets stay empty rather than drawing a sliver. */}
            {bin.count > 0 && (
              <div
                className={bin.from <= ceiling ? "w-[45%] rounded-t-[1px] bg-ink/55" : "w-[45%] rounded-t-[1px] bg-line"}
                style={{ height: `${(bin.count / maxCount) * 100}%` }}
              />
            )}
          </div>
        ))}
      </div>

      <div className="relative h-5">
        <div className="absolute inset-x-0 top-2 h-1 bg-line" />
        <div className="absolute left-0 top-2 h-1 bg-ink" style={{ width: `${pct}%` }} />
        <input
          type="range"
          aria-label={`Maximum ${fuel} price, cents per litre`}
          min={lo}
          max={hi}
          step={0.1}
          value={ceiling}
          onChange={(e) => move(Number(e.target.value))}
          className="absolute inset-0 h-5 w-full cursor-pointer appearance-none bg-transparent outline-none [&::-moz-range-thumb]:size-5 [&::-moz-range-thumb]:rounded-[50%] [&::-moz-range-thumb]:border-[1.5px] [&::-moz-range-thumb]:border-solid [&::-moz-range-thumb]:border-ink [&::-moz-range-thumb]:bg-surface [&::-moz-range-track]:h-5 [&::-moz-range-track]:bg-transparent [&::-webkit-slider-runnable-track]:h-5 [&::-webkit-slider-runnable-track]:bg-transparent [&::-webkit-slider-thumb]:size-5 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-[50%] [&::-webkit-slider-thumb]:border-[1.5px] [&::-webkit-slider-thumb]:border-ink [&::-webkit-slider-thumb]:bg-surface focus-visible:[&::-webkit-slider-thumb]:outline-[1.5px] focus-visible:[&::-webkit-slider-thumb]:outline-offset-2 focus-visible:[&::-webkit-slider-thumb]:outline-accent"
        />
      </div>

      <div className="flex justify-between text-[11px] text-ink-3 tabular-nums">
        <span>{formatPriceCents(lo)}</span>
        {average !== null && <span>Area avg {formatPriceCents(average)}</span>}
        <span>{formatPriceCents(hi)}</span>
      </div>
    </div>
  );
}
