import { FUEL_TYPES, type FuelType, type PriceSnapshot } from "@servo-map/shared";
import { changeOverDays, dayNumber, formatChange, latestAverage, seriesForFuel } from "@/lib/trends";
import { cn, formatPriceCents } from "@/lib/utils";
import { Card, ModuleNote } from "./Card";
import { Sparkline } from "./Sparkline";

interface FuelTableProps {
  /** Snapshots for every fuel, already limited to the selected range. */
  series: PriceSnapshot[];
  fuel: FuelType;
  stateLabel: string;
}

const TH = "px-2.5 py-2 text-left text-small font-normal text-ink-3";

/** All five fuels side by side: today's average, the gap to the selected fuel, and the week's move. */
export function FuelTable({ series, fuel, stateLabel }: FuelTableProps) {
  const selected = latestAverage(series, fuel);
  const rows = FUEL_TYPES.map((f) => ({ fuel: f, latest: latestAverage(series, f) })).filter(
    (r): r is { fuel: FuelType; latest: { date: string; avg: number } } => r.latest !== null,
  );

  return (
    <Card label="All fuels today" aside={`${stateLabel} average`}>
      {rows.length === 0 ? (
        <ModuleNote>No fuel averages reported for {stateLabel} yet.</ModuleNote>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-body">
            <thead>
              <tr>
                <th className={TH}>Fuel</th>
                <th className={cn(TH, "text-right")}>Avg</th>
                <th className={cn(TH, "text-right")}>vs {fuel}</th>
                <th className={cn(TH, "text-right")}>7 days</th>
                <th className={cn(TH, "max-sm:hidden")}>Trend</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const week = changeOverDays(series, r.fuel, 7);
                return (
                  <tr key={r.fuel} className="border-t border-line-subtle">
                    <td className={cn("px-2.5 py-2", r.fuel === fuel && "font-medium")}>{r.fuel}</td>
                    <td className="px-2.5 py-2 text-right font-display font-semibold tabular-nums">
                      {formatPriceCents(r.latest.avg)}
                    </td>
                    <td className="px-2.5 py-2 text-right tabular-nums text-ink-2">
                      {r.fuel === fuel || !selected ? "—" : formatChange(r.latest.avg - selected.avg)}
                    </td>
                    <td className={cn("px-2.5 py-2 text-right tabular-nums", weekTone(week))}>
                      {week === null ? "—" : formatChange(week)}
                    </td>
                    <td className="px-2.5 py-2 max-sm:hidden">
                      <Sparkline snapshots={lastDays(seriesForFuel(series, r.fuel), 30)} />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}

/** The trailing `days` of a series, so the word-sized line shows recent movement, not old gaps. */
function lastDays(snapshots: PriceSnapshot[], days: number): PriceSnapshot[] {
  const last = snapshots[snapshots.length - 1];
  return last ? snapshots.filter((s) => dayNumber(s.date) > dayNumber(last.date) - days) : snapshots;
}

function weekTone(change: number | null): string {
  if (change === null || formatChange(change) === "0.0") return "text-ink-2";
  return change > 0 ? "text-price-expensive" : "text-price-cheap";
}
