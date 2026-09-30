"use client";

import { useMemo, type ReactNode } from "react";
import type { AustralianState, FuelType, StationWithDistance } from "@servo-map/shared";
import type { TrendCycle } from "@/hooks/useTrends";
import { priceSpread } from "@/lib/aggregate";
import { STATE_LABELS } from "@/lib/coverage";
import type { SortMode } from "@/lib/filters";
import { LedgerNotice } from "./LedgerNotices";
import { LedgerRow } from "./LedgerRow";
import { LedgerSkeleton } from "./LedgerSkeleton";
import { Verdict } from "./Verdict";
import { OLD_PRICE_HOURS, cheapestRankedId, cheapestStation, rankStations } from "./rank";

interface LedgerProps {
  fuel: FuelType;
  sort: SortMode;
  /** Stations after filtering. */
  stations: StationWithDistance[];
  /** Stations the query returned, before filtering; tells "no coverage" from "filters too tight". */
  loadedCount: number;
  loading: boolean;
  error: string | null;
  onRetry: () => void;
  /** Set when a search matched nothing. */
  searchMiss: string | null;
  onClearSearch: () => void;
  noCoverage: boolean;
  liveStates: AustralianState[];
  filterCount: number;
  onResetFilters: () => void;
  place: string;
  cycle: TrendCycle | null;
  updatedAt: string | null;
  now: number;
  activeId: string | null;
  onSelect: (station: StationWithDistance) => void;
  isFavourite: (id: string) => boolean;
  onToggleFavourite: (id: string) => void;
  /** Quick filters and the sort switch, rendered between the verdict and the rows. */
  tools: ReactNode;
}

/** The ledger column: verdict, filter tools, then stations ranked by price with old prices set aside. */
export function Ledger(props: LedgerProps) {
  const { fuel, sort, stations, loading, now } = props;
  const ranked = useMemo(() => rankStations(stations, fuel, sort, now), [stations, fuel, sort, now]);
  const spread = useMemo(() => priceSpread(stations, fuel), [stations, fuel]);
  const cheapest = useMemo(() => cheapestStation(stations, fuel, now), [stations, fuel, now]);
  const cheapestId = useMemo(() => cheapestRankedId(stations, fuel, now), [stations, fuel, now]);

  const firstLoad = loading && props.loadedCount === 0;

  return (
    <div className="md:flex md:min-h-0 md:flex-1 md:flex-col">
      {cheapest && (
        <Verdict
          fuel={fuel}
          place={props.place}
          cheapest={cheapest}
          count={stations.length}
          spread={spread}
          cycle={props.cycle}
          updatedAt={props.updatedAt}
          refreshing={loading}
        />
      )}
      {props.tools}
      <div className="md:min-h-0 md:flex-1 md:overflow-y-auto">
        {props.error && !loading && (
          <LedgerNotice
            title="Couldn’t load fuel prices"
            action={{ label: "Retry", onClick: props.onRetry, primary: true }}
          >
            Check your connection and try again.
          </LedgerNotice>
        )}
        {props.searchMiss && !loading && !props.error && (
          <LedgerNotice
            title={`No stations found for “${props.searchMiss}”`}
            action={{ label: "Clear search", onClick: props.onClearSearch }}
          >
            {props.liveStates.length > 0
              ? `Live now: ${props.liveStates.map((s) => STATE_LABELS[s]).join(", ")}.`
              : "Try a suburb or postcode."}
          </LedgerNotice>
        )}
        {firstLoad ? (
          <LedgerSkeleton />
        ) : props.noCoverage ? (
          <LedgerNotice title="No live prices in this area yet">
            {props.liveStates.length > 0
              ? `Live now: ${props.liveStates.map((s) => STATE_LABELS[s]).join(", ")}. Pan to a covered area or search a ${STATE_LABELS[props.liveStates[0]]} suburb.`
              : "Coverage is rolling out. Pan to a covered area or try a search."}
          </LedgerNotice>
        ) : stations.length === 0 && !loading && !props.error ? (
          <LedgerNotice
            title="No stations match"
            action={
              props.filterCount > 0
                ? { label: "Reset filters", onClick: props.onResetFilters }
                : undefined
            }
          >
            {props.filterCount > 0
              ? "These filters leave nothing in view."
              : "Try searching a different area."}
          </LedgerNotice>
        ) : (
          <StationRows {...props} ranked={ranked} cheapestId={cheapestId} />
        )}
      </div>
    </div>
  );
}

function StationRows({
  ranked,
  cheapestId,
  fuel,
  activeId,
  onSelect,
  isFavourite,
  onToggleFavourite,
}: LedgerProps & { ranked: ReturnType<typeof rankStations>; cheapestId: string | null }) {
  const row = (station: StationWithDistance, rank: number | null) => (
    <LedgerRow
      key={station.id}
      station={station}
      fuel={fuel}
      rank={rank}
      cheapest={station.id === cheapestId}
      active={activeId === station.id}
      favourite={isFavourite(station.id)}
      onSelect={onSelect}
      onToggleFavourite={onToggleFavourite}
    />
  );

  return (
    <ul aria-label="Stations">
      {ranked.fresh.map((s, i) => row(s, i + 1))}
      {ranked.old.length > 0 && (
        <li className="border-b border-line-subtle bg-bg px-5 py-[7px]">
          <span className="caption">
            {ranked.old.length} station{ranked.old.length === 1 ? "" : "s"} not updated in {OLD_PRICE_HOURS} h
          </span>
        </li>
      )}
      {ranked.old.map((s) => row(s, null))}
    </ul>
  );
}
