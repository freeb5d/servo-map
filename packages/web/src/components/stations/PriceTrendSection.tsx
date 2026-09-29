import type { FuelType, PriceSnapshot } from "@servo-map/shared";
import { PriceTrendChart } from "./PriceTrendChart";
import { cheapestDayToFill, seriesForFuel } from "@/lib/trends";
import { formatPriceCents } from "@/lib/utils";

interface Props {
  series: PriceSnapshot[];
  fuel: FuelType;
  /** Uppercase state code, e.g. "NSW" — labels the (state-level) trend. */
  stateLabel: string;
}

/**
 * "Price trend" section: the chart plus the cheapest-day insight (the cycle verdict sits in the page's side column). History is captured
 * per state, so this is honestly labelled as the state's trend rather than the suburb's. Renders
 * nothing if the fuel has no snapshots — callers also guard on an empty series.
 */
export function PriceTrendSection({ series, fuel, stateLabel }: Props) {
  if (seriesForFuel(series, fuel).length === 0) return null;
  const cheapest = cheapestDayToFill(series, fuel);

  return (
    <section className="grid gap-3 animate-rise-in">
      <div className="grid gap-1">
        <h2 className="caption">Price trend</h2>
        <p className="text-small text-ink-3">
          {stateLabel} {fuel} daily average across the state. Updated daily.
        </p>
      </div>

      <PriceTrendChart series={series} fuel={fuel} state={stateLabel} />

      {cheapest && (
        <p className="text-body text-ink-2">
          Cheapest day to fill in {stateLabel}: <span className="font-semibold text-ink">{cheapest.weekday}</span>{" "}
          <span className="text-ink-3">(avg {formatPriceCents(cheapest.avg)}c)</span>
        </p>
      )}
    </section>
  );
}
