"use client";

import type { FuelType } from "@servo-map/shared";
import { BrandSeal } from "@/components/ui/BrandSeal";
import { brandStats } from "@/lib/aggregate";
import { formatPriceCents } from "@/lib/utils";
import { Card } from "./Card";
import { NearGate } from "./NearGate";
import { NEAR_RADIUS_KM, type NearYou } from "./useNearYou";

interface BrandLeagueProps {
  near: NearYou;
  fuel: FuelType;
}

const ROW = "grid grid-cols-[38px_1fr_64px] sm:grid-cols-[38px_104px_1fr_64px] items-center gap-3 py-1.5";

/**
 * Brand families ranked by average price, as a dot plot on one shared scale. Dots need no zero
 * baseline, so the chart stays honest without a caption explaining a truncated axis.
 */
export function BrandLeague({ near, fuel }: BrandLeagueProps) {
  return (
    <Card label={`Brands within ${NEAR_RADIUS_KM} km`} aside={`average ${fuel}`}>
      <NearGate near={near} fuel={fuel}>
        {(stations) => {
          const stats = brandStats(stations, fuel);
          const lo = stats[0].avg;
          const hi = stats[stats.length - 1].avg;
          const pct = (v: number): number => (hi > lo ? ((v - lo) / (hi - lo)) * 100 : 50);

          return (
            <ol className="grid">
              {stats.map(({ family, avg, count }) => (
                <li key={family.id} className={ROW}>
                  <BrandSeal brand={family.name} />
                  <span className="max-sm:hidden truncate text-body">
                    {family.name}
                    <span className="ml-1.5 text-small text-ink-3">{count}</span>
                  </span>
                  <span className="relative h-px bg-line-subtle max-sm:hidden" aria-hidden="true">
                    <span
                      className="absolute top-1/2 size-2 -translate-x-1/2 -translate-y-1/2 rounded-[50%] bg-ink"
                      style={{ left: `${pct(avg)}%` }}
                    />
                  </span>
                  <span className="text-right font-display font-semibold tabular-nums">{formatPriceCents(avg)}</span>
                </li>
              ))}
            </ol>
          );
        }}
      </NearGate>
    </Card>
  );
}
