"use client";

import type { FuelType, PriceSnapshot } from "@servo-map/shared";
import { priceSpread } from "@/lib/aggregate";
import { useLocalStorage } from "@/hooks/useLocalStorage";
import { annualSaving, latestAverage, weekdaySpread } from "@/lib/trends";
import { NumberField } from "./NumberField";
import { Card } from "./Card";
import { NEAR_RADIUS_KM, type NearYou } from "./useNearYou";

interface SavingsCalculatorProps {
  series: PriceSnapshot[];
  fuel: FuelType;
  near: NearYou;
}

interface Habit {
  litres: number;
  fills: number;
}

const DEFAULT_HABIT: Habit = { litres: 50, fills: 3 };

/** "What choosing well is worth": what the price gaps above add up to over a year of your fills. */
export function SavingsCalculator({ series, fuel, near }: SavingsCalculatorProps) {
  const [habit, setHabit] = useLocalStorage<Habit>("servo-map:calc", DEFAULT_HABIT);
  // Stored values can be stale or hand-edited; fall back rather than multiply garbage.
  const litres = habit.litres > 0 ? habit.litres : DEFAULT_HABIT.litres;
  const fills = habit.fills > 0 ? habit.fills : DEFAULT_HABIT.fills;
  const yearlyFills = Math.round(fills * 12 * 10) / 10;

  const weekday = weekdaySpread(series, fuel);
  const u91 = latestAverage(series, "U91");
  const e10 = latestAverage(series, "E10");
  const spread = near.status === "ready" ? priceSpread(near.stations, fuel) : null;

  const result = (cents: number): { value: string; formula: string } => ({
    value: `$${annualSaving(cents, litres, fills)} / yr`,
    formula: `${cents.toFixed(1)}¢/L × ${litres} L × ${yearlyFills} fills`,
  });

  const nearby = spread ? result(spread.avg - spread.min) : null;
  const byDay = weekday ? result(weekday.gap) : null;
  const e10Gap = u91 && e10 ? u91.avg - e10.avg : null;

  return (
    <Card label="Over a year" aside="saved on this device">
      <div className="flex flex-wrap gap-x-6 gap-y-2">
        <NumberField label="Tank fill" value={litres} min={1} max={200} suffix="L" onCommit={(n) => setHabit({ ...habit, litres: n })} />
        <NumberField label="Fills a month" value={fills} min={0.5} max={31} onCommit={(n) => setHabit({ ...habit, fills: n })} />
      </div>
      <div className="grid gap-4 md:grid-cols-3">
        <Outcome
          label={`Cheapest nearby vs average`}
          result={nearby}
          empty={near.status === "loading" ? `Waiting for stations within ${NEAR_RADIUS_KM} km.` : `No nearby ${fuel} prices to compare.`}
        />
        <Outcome
          label={weekday ? `${weekday.cheapest.weekday} vs ${weekday.dearest.weekday}` : "Cheapest weekday vs dearest"}
          result={byDay}
          empty="Not enough days of history to compare weekdays."
        />
        {e10Gap !== null && (
          <Outcome
            label="E10 instead of U91"
            result={e10Gap > 0 ? result(e10Gap) : null}
            empty={`E10 is not cheaper than U91 today.`}
            suffix={e10Gap > 0 ? ", if your car takes E10" : ""}
          />
        )}
      </div>
    </Card>
  );
}

interface OutcomeProps {
  label: string;
  result: { value: string; formula: string } | null;
  empty: string;
  suffix?: string;
}

function Outcome({ label, result, empty, suffix = "" }: OutcomeProps) {
  return (
    <div className="grid gap-1">
      <span className="text-small text-ink-3">{label}</span>
      {result ? (
        <>
          <span className="font-display text-[26px] font-semibold leading-tight tabular-nums">{result.value}</span>
          <span className="text-body text-ink-2">
            {result.formula}
            {suffix}
          </span>
        </>
      ) : (
        <span className="text-body text-ink-2">{empty}</span>
      )}
    </div>
  );
}
