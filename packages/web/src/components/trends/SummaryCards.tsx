"use client";

import type { FuelType, PriceSnapshot } from "@servo-map/shared";
import { priceSpread } from "@/lib/aggregate";
import {
  changeOverDays,
  cyclePosition,
  formatChange,
  formatShortDate,
  latestAverage,
  weekdaySpread,
} from "@/lib/trends";
import { formatPriceCents } from "@/lib/utils";
import { Card, ModuleNote } from "./Card";
import { RangeLine } from "@/components/ui/RangeLine";
import { NearGate } from "./NearGate";
import { NEAR_RADIUS_KM, type NearYou } from "./useNearYou";

interface SummaryCardsProps {
  /** Snapshots already limited to the selected range. */
  series: PriceSnapshot[];
  fuel: FuelType;
  range: number;
  near: NearYou;
}

const FIG = "font-display text-[30px] font-semibold leading-[1.1] tabular-nums";
/** Four figures under the headline, ruled like a newspaper table rather than boxed as tiles. */
export function SummaryCards({ series, fuel, range, near }: SummaryCardsProps) {
  const cycle = cyclePosition(series, fuel);
  const latest = latestAverage(series, fuel);
  const week = changeOverDays(series, fuel, 7);
  const weekday = weekdaySpread(series, fuel);
  const isToday = latest?.date === new Date().toISOString().slice(0, 10);

  return (
    <div className="grid grid-cols-2 gap-x-6 gap-y-8 lg:grid-cols-4 lg:gap-x-10">
      <Card label={`Last ${range} days`}>
        {cycle ? (
          <>
            <RangeLine min={cycle.min} max={cycle.max} current={cycle.current} days={range} />
          </>
        ) : (
          <ModuleNote>No {fuel} history to place today in.</ModuleNote>
        )}
      </Card>

      <Card label={isToday || !latest ? "State average" : `State average, ${formatShortDate(latest.date)}`}>
        {latest ? (
          <>
            <span className={FIG}>{formatPriceCents(latest.avg)}</span>
            <WeekChange change={week} />
          </>
        ) : (
          <ModuleNote>No {fuel} average reported yet.</ModuleNote>
        )}
      </Card>

      <Card label={`Spread within ${NEAR_RADIUS_KM} km`}>
        <NearGate near={near} fuel={fuel}>
          {(stations) => {
            const spread = priceSpread(stations, fuel);
            if (!spread) return null;
            return (
              <>
                <span className={FIG}>{formatPriceCents(spread.max - spread.min)}&cent;</span>
                <p className="text-body text-ink-2">
                  {formatPriceCents(spread.min)} to {formatPriceCents(spread.max)}
                </p>
              </>
            );
          }}
        </NearGate>
      </Card>

      <Card label="Cheapest day">
        {weekday ? (
          <>
            <span className={FIG}>{weekday.cheapest.weekday}</span>
            <p className="text-body text-ink-2">
              {formatPriceCents(weekday.gap)}&cent; under {weekday.dearest.weekday}
            </p>
          </>
        ) : (
          <ModuleNote>Not enough days of history to compare weekdays.</ModuleNote>
        )}
      </Card>
    </div>
  );
}

function WeekChange({ change }: { change: number | null }) {
  if (change === null) return <p className="text-body text-ink-2">No figure from a week ago.</p>;
  if (formatChange(change) === "0.0") return <p className="text-body text-ink-2">Unchanged on last week</p>;
  return (
    <p className={change > 0 ? "text-body text-price-expensive" : "text-body text-price-cheap"}>
      {formatChange(change)} on last week
    </p>
  );
}
