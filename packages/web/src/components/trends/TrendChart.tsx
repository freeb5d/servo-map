"use client";

import { useId, useState, type PointerEvent } from "react";
import type { FuelType, PriceSnapshot } from "@servo-map/shared";
import { areaPath, monthTicks, smoothPath, type Point } from "@/lib/chart-geometry";
import { dailyGaps, dayNumber, formatShortDate, seriesForFuel, splitAtGaps, trendDomain } from "@/lib/trends";
import { formatPriceCents } from "@/lib/utils";
import { useElementWidth } from "./useElementWidth";
import { ModuleNote } from "./Card";

interface TrendChartProps {
  /** Daily snapshots for every fuel in the window, ascending by date. */
  series: PriceSnapshot[];
  fuel: FuelType;
  /** Second fuel drawn dashed for comparison; omitted when null. */
  compareFuel?: FuelType | null;
  /** Scope for the accessible summary, e.g. "NSW". */
  stateLabel: string;
  height?: number;
}

const PAD = { left: 36, right: 14, top: 18, bottom: 24 } as const;
const CHAR_PX = 5.6;

/**
 * Daily average on a real calendar axis, styled after evilcharts.com: a soft gradient under the
 * line, a dashed comparison fuel, a faint horizontal grid only, hollow dots where each run ends,
 * and a hover read-out. Missing days keep their width and the line breaks there, never bridging.
 */
export function TrendChart({ series, fuel, compareFuel = null, stateLabel, height = 230 }: TrendChartProps) {
  const [ref, width] = useElementWidth<HTMLDivElement>(640);
  const gradientId = `area-${useId().replace(/[^a-zA-Z0-9_-]/g, "")}`;
  const [hover, setHover] = useState<PriceSnapshot | null>(null);

  const main = seriesForFuel(series, fuel);
  if (main.length < 2) return <ModuleNote>Not enough {fuel} history yet to draw a trend.</ModuleNote>;

  const day0 = dayNumber(main[0].date);
  const day1 = dayNumber(main[main.length - 1].date);
  const compare = compareFuel
    ? seriesForFuel(series, compareFuel).filter((s) => dayNumber(s.date) >= day0 && dayNumber(s.date) <= day1)
    : [];
  const domain = trendDomain([...main, ...compare]);
  const innerW = width - PAD.left - PAD.right;
  const innerH = height - PAD.top - PAD.bottom;
  const baseline = PAD.top + innerH;
  const xOfDay = (day: number): number => PAD.left + ((day - day0) / (day1 - day0 || 1)) * innerW;
  const xOf = (date: string): number => xOfDay(dayNumber(date));
  const yOf = (price: number): number => PAD.top + innerH - ((price - domain.lo) / (domain.hi - domain.lo)) * innerH;
  const pts = (run: PriceSnapshot[]): Point[] => run.map((s) => ({ x: xOf(s.date), y: yOf(s.avg) }));

  const latest = main[main.length - 1];
  const low = main.reduce((best, s) => (s.avg < best.avg ? s : best), main[0]);
  const gaps = dailyGaps(series, fuel).filter((g) => dayNumber(g.from) >= day0 && dayNumber(g.to) <= day1);
  const summary =
    `${stateLabel} ${fuel} daily average: low ${formatPriceCents(low.avg)} on ${formatShortDate(low.date)}, ` +
    `now ${formatPriceCents(latest.avg)}` +
    (gaps.length ? `, no data ${gaps.map((g) => `${formatShortDate(g.from)} to ${formatShortDate(g.to)}`).join(", ")}` : "") +
    ".";

  // Snap the read-out to the nearest reported day under the pointer.
  const onMove = (e: PointerEvent<SVGSVGElement>) => {
    const x = e.clientX - e.currentTarget.getBoundingClientRect().left;
    const day = day0 + ((x - PAD.left) / innerW) * (day1 - day0);
    setHover(main.reduce((best, s) => (Math.abs(dayNumber(s.date) - day) < Math.abs(dayNumber(best.date) - day) ? s : best)));
  };

  return (
    <div ref={ref} className="grid w-full min-w-0 gap-1 overflow-hidden">
      <Legend fuel={fuel} compareFuel={compare.length > 0 ? compareFuel : null} />
      <svg
        width={width}
        height={height}
        viewBox={`0 0 ${width} ${height}`}
        role="img"
        aria-label={summary}
        className="block touch-pan-y"
        onPointerMove={onMove}
        onPointerLeave={() => setHover(null)}
      >
        <defs>
          <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--color-ink)" stopOpacity="0.16" />
            <stop offset="100%" stopColor="var(--color-ink)" stopOpacity="0" />
          </linearGradient>
        </defs>

        {domain.ticks.map((tick) => (
          <g key={tick}>
            <line x1={PAD.left} x2={width - PAD.right} y1={yOf(tick)} y2={yOf(tick)} strokeDasharray="2 3" className="stroke-line" />
            <text x={PAD.left - 8} y={yOf(tick) + 3.5} textAnchor="end" fontSize="10" className="fill-ink-3 tabular-nums">
              {tick}
            </text>
          </g>
        ))}

        {gaps.map((g) => {
          const x0 = xOf(g.after);
          const x1 = xOf(g.before);
          return (
            <g key={g.from}>
              <rect x={x0} y={PAD.top} width={x1 - x0} height={innerH} className="fill-wash" fillOpacity="0.6" />
              {x1 - x0 >= 7 * CHAR_PX + 12 && (
                <text x={(x0 + x1) / 2} y={PAD.top + innerH / 2} textAnchor="middle" fontSize="11" className="fill-ink-3">
                  No data
                </text>
              )}
            </g>
          );
        })}

        {splitAtGaps(compare).map((run) => (
          <path key={`c-${run[0].date}`} d={smoothPath(pts(run))} fill="none" strokeWidth="1.2" strokeDasharray="3 3" className="stroke-ink-3" />
        ))}

        {splitAtGaps(main).map((run) => (
          <g key={run[0].date}>
            <path d={areaPath(pts(run), baseline)} fill={`url(#${gradientId})`} />
            <path d={smoothPath(pts(run))} fill="none" strokeWidth="1.8" strokeLinecap="round" className="stroke-ink" />
            <circle cx={xOf(run[run.length - 1].date)} cy={yOf(run[run.length - 1].avg)} r="3.5" strokeWidth="1.5" className="fill-surface stroke-ink" />
          </g>
        ))}

        {hover ? (
          <ReadOut x={xOf(hover.date)} y={yOf(hover.avg)} snapshot={hover} top={PAD.top} bottom={baseline} width={width} />
        ) : (
          <text x={Math.min(xOf(latest.date), width - PAD.right)} y={yOf(latest.avg) - 10} textAnchor="end" fontSize="11" className="fill-ink-2 tabular-nums">
            {formatPriceCents(latest.avg)}
          </text>
        )}

        {monthTicks(day0, day1).map((t) => (
          <text key={t.day} x={xOfDay(t.day)} y={height - 6} textAnchor="middle" fontSize="10" className="fill-ink-3">
            {t.label}
          </text>
        ))}
      </svg>
    </div>
  );
}

function Legend({ fuel, compareFuel }: { fuel: FuelType; compareFuel: FuelType | null }) {
  return (
    <div aria-hidden="true" className="flex justify-end gap-4 text-small text-ink-2">
      <span className="inline-flex items-center gap-1.5">
        <span className="h-[2px] w-3.5 bg-ink" />
        {fuel}
      </span>
      {compareFuel && (
        <span className="inline-flex items-center gap-1.5">
          <span className="w-3.5 border-t-[1.5px] border-dashed border-ink-3" />
          {compareFuel}
        </span>
      )}
    </div>
  );
}

interface ReadOutProps {
  x: number;
  y: number;
  snapshot: PriceSnapshot;
  top: number;
  bottom: number;
  width: number;
}

/** Dashed rule, a filled dot and the day's value above it, kept inside the frame. */
function ReadOut({ x, y, snapshot, top, bottom, width }: ReadOutProps) {
  const text = `${formatPriceCents(snapshot.avg)}  ${formatShortDate(snapshot.date)}`;
  const w = text.length * CHAR_PX + 16;
  const left = Math.min(Math.max(x - w / 2, PAD.left), width - PAD.right - w);
  const boxY = Math.max(top - 16, y - 34);
  return (
    <g pointerEvents="none">
      <line x1={x} x2={x} y1={top} y2={bottom} strokeDasharray="2 3" className="stroke-ink-3" />
      <circle cx={x} cy={y} r="4.5" strokeWidth="2" className="fill-ink stroke-surface" />
      <rect x={left} y={boxY} width={w} height="20" rx="3" strokeWidth="1" className="fill-surface stroke-line" />
      <text x={left + w / 2} y={boxY + 14} textAnchor="middle" fontSize="11" className="fill-ink tabular-nums">
        {text}
      </text>
    </g>
  );
}
