import type { FuelType, PriceSnapshot } from "@servo-map/shared";
import { TrendChart } from "@/components/trends/TrendChart";

interface Props {
  series: PriceSnapshot[];
  fuel: FuelType;
  /** Human label for the trend's scope, e.g. "NSW" — used in the aria summary. */
  state: string;
  /** Optional caption rendered above the chart. */
  label?: string;
}

/**
 * Price trend for one fuel on the SEO pages: the same chart as /trends (real calendar axis,
 * open data gaps, a dashed comparison fuel) inside a paper card. Renders TrendChart's own
 * "not enough history" note when there are fewer than two days.
 */
export function PriceTrendChart({ series, fuel, state, label }: Props) {
  return (
    <figure className="rounded-3 border border-line-subtle bg-surface px-[18px] py-4">
      {label && <figcaption className="caption mb-3">{label}</figcaption>}
      <TrendChart series={series} fuel={fuel} compareFuel={fuel === "U91" ? "E10" : "U91"} stateLabel={state} />
    </figure>
  );
}
