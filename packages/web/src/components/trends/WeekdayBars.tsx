import type { FuelType, PriceSnapshot } from "@servo-map/shared";
import { weekdayAverages } from "@/lib/trends";
import { cn, formatPriceCents } from "@/lib/utils";
import { Card, ModuleNote } from "./Card";

interface WeekdayBarsProps {
  /** Snapshots already limited to the selected range. */
  series: PriceSnapshot[];
  fuel: FuelType;
  range: number;
}

/**
 * Weekday averages as dots on a shared scale (after the evilcharts dot style). Dots need no zero
 * baseline, so the chart stays honest without a caption; the cheapest day is the green dot.
 */
export function WeekdayBars({ series, fuel, range }: WeekdayBarsProps) {
  const days = weekdayAverages(series, fuel);
  const known = days.flatMap((d) => (d.avg === null ? [] : [d.avg]));
  const min = Math.min(...known);
  const max = Math.max(...known);
  // Dots sit between 12% and 72% of the column so the value label above never clips.
  const bottom = (avg: number): string => `${12 + (max > min ? ((avg - min) / (max - min)) * 60 : 30)}%`;

  return (
    <Card label="By weekday" aside={`last ${range} days`}>
      {known.length < 2 ? (
        <ModuleNote>Not enough days of {fuel} history to compare weekdays.</ModuleNote>
      ) : (
        <ol className="grid grid-cols-7">
          {days.map((d) => (
            <li key={d.weekday} className="grid gap-1.5 text-center">
              <div className="relative h-[110px] border-b border-dashed border-line">
                {d.avg !== null && (
                  <div className="absolute inset-x-0 grid justify-items-center gap-1" style={{ bottom: bottom(d.avg) }}>
                    <span className={cn("text-[11px] tabular-nums", d.avg === min ? "font-semibold text-ink" : "text-ink-3")}>
                      {formatPriceCents(d.avg)}
                    </span>
                    <span
                      aria-hidden="true"
                      className={cn("rounded-[50%]", d.avg === min ? "size-3 bg-price-cheap" : "size-2 bg-ink-2")}
                    />
                  </div>
                )}
              </div>
              <span className={cn("text-small", d.avg === min ? "font-medium text-ink" : "text-ink-3")}>{d.short}</span>
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}
