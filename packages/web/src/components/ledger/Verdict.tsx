import type { FuelType, StationWithDistance } from "@servo-map/shared";
import type { PriceSpread } from "@/lib/aggregate";
import type { TrendCycle } from "@/hooks/useTrends";
import { BrandSeal } from "@/components/ui/BrandSeal";
import { formatPriceCents, getFuelPrice, isStale, timeAgo } from "@/lib/utils";
import { cycleVerdict } from "@/lib/trends";
import { RangeLine } from "@/components/ui/RangeLine";

interface VerdictProps {
  fuel: FuelType;
  /** Searched suburb, "you" once located, else the default view's name. */
  place: string;
  cheapest: StationWithDistance;
  count: number;
  spread: PriceSpread | null;
  cycle: TrendCycle | null;
  /** Newest feed update in view; null while metadata is unavailable. */
  updatedAt: string | null;
  refreshing: boolean;
}

/** "What is cheapest near here, and should I fill up now?", answered before any list. */
export function Verdict({
  fuel,
  place,
  cheapest,
  count,
  spread,
  cycle,
  updatedAt,
  refreshing,
}: VerdictProps) {
  const price = getFuelPrice(cheapest.prices, fuel)?.price ?? 0;
  const under = spread ? spread.avg - price : 0;
  const underText =
    spread && under >= 0.1
      ? `${formatPriceCents(under)}¢ below the local average of ${formatPriceCents(spread.avg)}.`
      : null;
  const stale = updatedAt !== null && isStale(updatedAt);

  return (
    <section aria-label="Price verdict" className="grid gap-[9px] border-b border-line px-5 pt-4 pb-3.5">
      <div className="flex items-baseline justify-between gap-3">
        <h2 className="text-small font-semibold text-price-cheap">
          Cheapest {fuel} near {place}
        </h2>
        {!stale && (updatedAt || refreshing) && (
          <span className="text-[10.5px] text-ink-3">
            {refreshing ? "Updating…" : `Updated ${timeAgo(updatedAt as string)}`}
          </span>
        )}
      </div>

      <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <span className="font-display text-[34px] md:text-[40px] leading-none font-semibold tabular-nums text-ink">
          {formatPriceCents(price)}
          <span className="ml-0.5 font-body text-[0.45em] font-normal text-ink-3">¢/L</span>
        </span>
        <span className="flex min-w-0 items-center gap-1.5 text-body text-ink-2">
          <BrandSeal brand={cheapest.brand} />
          <span className="truncate">{cheapest.suburb}</span>
          <span className="shrink-0 text-small text-ink-3">lowest of {count}</span>
        </span>
      </div>

      {stale && updatedAt && (
        <p role="status" className="text-small text-price-expensive">
          Prices may be out of date — last updated {timeAgo(updatedAt)}.
        </p>
      )}

      {(cycle || underText) && (
        <p className="text-body text-ink-2">
          {cycle && <span className="text-ink">{cycleVerdict(cycle.position, cycle.current === cycle.max, cycle.days)} </span>}
          {underText}
        </p>
      )}
      {cycle && <RangeLine min={cycle.min} max={cycle.max} current={cycle.current} days={cycle.days} />}
    </section>
  );
}
