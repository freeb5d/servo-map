"use client";

import type { AustralianState, FuelType, PriceSnapshot } from "@servo-map/shared";
import { TopBar } from "@/components/shell/TopBar";
import { MobileTabs } from "@/components/shell/MobileTabs";
import { STATE_LABELS } from "@/lib/coverage";
import {
  cyclePosition,
  cycleVerdict,
  formatShortDate,
  seriesForFuel,
  windowSeries,
  windowSpanDays,
} from "@/lib/trends";
import { BrandLeague } from "./BrandLeague";
import { Card, ModuleNote } from "./Card";
import { FuelTable } from "./FuelTable";
import { SavingsCalculator } from "./SavingsCalculator";
import { SuburbTables } from "./SuburbTables";
import { SummaryCards } from "./SummaryCards";
import { TrendChart } from "./TrendChart";
import { TrendsHeader } from "./TrendsHeader";
import { WeekdayBars } from "./WeekdayBars";
import { useNearYou } from "./useNearYou";
import { useTrendsParams } from "./useTrendsParams";

/** One live state and its price history; series is null when the history request failed. */
export interface TrendState {
  state: AustralianState;
  series: PriceSnapshot[] | null;
}

function headline(series: PriceSnapshot[] | null, fuel: FuelType, range: number, stateLabel: string): string {
  if (series === null) return `${stateLabel} price history is unavailable right now.`;
  const cycle = cyclePosition(series, fuel);
  if (!cycle) return `There is no ${fuel} price history for ${stateLabel} yet.`;
  const days = Math.min(range, windowSpanDays(series, fuel));
  return cycleVerdict(cycle.position, cycle.current === cycle.max, days);
}

/** The /trends page: verdict, cycle, chart with honest gaps, and the nearby rankings. */
export function TrendsView({ states }: { states: TrendState[] }) {
  const params = useTrendsParams(states.map((s) => s.state));
  const { state, fuel, range } = params;
  const near = useNearYou(state);
  const stateLabel = STATE_LABELS[state];

  const full = states.find((s) => s.state === state)?.series ?? null;
  const series = full ? windowSeries(full, range) : null;
  const snapshots = series ? seriesForFuel(series, fuel) : [];

  return (
    <div className="min-h-screen bg-bg pb-[calc(72px+env(safe-area-inset-bottom))] md:pb-0">
      <TopBar active="trends" fuel={fuel} onFuelChange={params.setFuel} onLocate={near.locateMe} locating={near.locating} />
      <main className="mx-auto grid grid-cols-[minmax(0,1fr)] max-w-[1080px] gap-10 px-4 pb-16 pt-8 md:px-12 md:pt-12">
        <TrendsHeader
          eyebrow={`${stateLabel} ${fuel}, updated daily`}
          headline={headline(series, fuel, range, stateLabel)}
          states={states.map((s) => ({ state: s.state, label: STATE_LABELS[s.state] }))}
          state={state}
          onState={params.setState}
          range={range}
          onRange={params.setRange}
          placeLabel={near.place.label}
          onLocate={near.locateMe}
          locating={near.locating}
          locationError={near.locationError}
        />

        {series === null ? (
          <Card label="Price history">
            <ModuleNote>
              We couldn&rsquo;t load {stateLabel} price history just now. Reload in a few minutes; the nearby
              rankings below don&rsquo;t depend on it.
            </ModuleNote>
          </Card>
        ) : (
          <SummaryCards series={series} fuel={fuel} range={range} near={near} />
        )}

        {series !== null && (
          <Card
            label={
              snapshots.length > 0
                ? "Daily average"
                : "Daily average"
            }
          >
            <TrendChart series={series} fuel={fuel} compareFuel={fuel === "U91" ? "E10" : "U91"} stateLabel={stateLabel} />
          </Card>
        )}

        <div className="grid gap-10 lg:grid-cols-2 lg:gap-12">
          {series !== null && <FuelTable series={series} fuel={fuel} stateLabel={stateLabel} />}
          <BrandLeague near={near} fuel={fuel} />
        </div>

        <div className="grid gap-10 lg:grid-cols-3 lg:gap-12">
          <SuburbTables near={near} fuel={fuel} className="lg:col-span-2" />
          {series !== null && <WeekdayBars series={series} fuel={fuel} range={range} />}
        </div>

        {series !== null && <SavingsCalculator series={series} fuel={fuel} near={near} />}
      </main>
      <MobileTabs active="trends" />
    </div>
  );
}
