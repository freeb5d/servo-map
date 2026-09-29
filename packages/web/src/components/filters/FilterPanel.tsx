"use client";

import { useMemo, useRef, type RefObject } from "react";
import { FUEL_TYPES, type FuelType, type StationWithDistance } from "@servo-map/shared";
import { Icon } from "@/components/ui/Icon";
import { priceSpread } from "@/lib/aggregate";
import {
  FRESH_OPTIONS,
  KM_OPTIONS,
  activeFilterCount,
  applyFilters,
  type MapFilters,
} from "@/lib/filters";
import { cn, getFuelPrice } from "@/lib/utils";
import { BrandSection } from "./BrandSection";
import { FilterChip } from "./FilterChip";
import { PriceCeiling } from "./PriceCeiling";
import { SegSection } from "./SegSection";
import { useDismiss } from "./useDismiss";

interface FilterPanelProps {
  fuel: FuelType;
  filters: MapFilters;
  onChange: (update: Partial<MapFilters>) => void;
  /** Every station the query returned; the panel derives the price shape and brand counts from it. */
  stations: StationWithDistance[];
  origin: { lat: number; lng: number } | null;
  /** True when the origin is the viewer's position rather than the map centre. */
  located: boolean;
  now: number;
  /** Stations the current filters leave in, for the "Show n stations" button. */
  shownCount: number;
  onReset: () => void;
  onSavePreset: () => void;
  onClose: () => void;
  triggerRef: RefObject<HTMLButtonElement | null>;
  /** Floating popover over the map on desktop; fills its container in a phone sheet. */
  variant: "popover" | "sheet";
}

const DISTANCE_OPTIONS = [
  ...KM_OPTIONS.map((km) => ({ value: km as number | undefined, label: `${km} km` })),
  { value: undefined, label: "Any" },
];
const FRESH_CHOICES = [
  ...FRESH_OPTIONS.map((h) => ({ value: h as number | undefined, label: `${h} h` })),
  { value: undefined, label: "Any" },
];

/** The full filter panel: price ceiling, distance, price age, brands and other fuels. */
export function FilterPanel({
  fuel,
  filters,
  onChange,
  stations,
  origin,
  located,
  now,
  shownCount,
  onReset,
  onSavePreset,
  onClose,
  triggerRef,
  variant,
}: FilterPanelProps) {
  const panelRef = useRef<HTMLDivElement>(null);
  useDismiss({ onClose, panelRef, triggerRef, closeOnOutsideClick: variant === "popover" });

  // The ceiling and the brand list describe what the *other* filters leave in, so they do not
  // collapse as the viewer tightens the control they are looking at.
  const priceScope = useMemo(
    () => applyFilters(stations, { ...filters, max: undefined }, fuel, origin, now),
    [stations, filters, fuel, origin, now],
  );
  const brandScope = useMemo(
    () =>
      applyFilters(
        stations,
        { ...filters, brands: [], group: undefined, noMembers: false },
        fuel,
        origin,
        now,
      ),
    [stations, filters, fuel, origin, now],
  );
  const prices = useMemo(
    () => priceScope.map((s) => getFuelPrice(s.prices, fuel)!.price),
    [priceScope, fuel],
  );
  const average = useMemo(() => priceSpread(priceScope, fuel)?.avg ?? null, [priceScope, fuel]);
  const others = FUEL_TYPES.filter((f) => f !== fuel);
  const count = activeFilterCount(filters);

  const toggleAlso = (f: FuelType) =>
    onChange({ also: filters.also.includes(f) ? filters.also.filter((x) => x !== f) : [...filters.also, f] });

  return (
    <div
      ref={panelRef}
      role="dialog"
      aria-label="Filters"
      tabIndex={-1}
      className={cn(
        "flex min-h-0 flex-col bg-surface outline-none animate-rise-in",
        variant === "popover" ? "floating rounded-3 overflow-hidden" : "h-full",
      )}
    >
      <header className="flex items-center justify-between border-b border-line-subtle px-[18px] py-3.5">
        <h2 className="font-display text-[18px] font-semibold text-ink">Filters</h2>
        <button type="button" className="icon-btn" aria-label="Close filters" onClick={onClose}>
          <Icon name="close" />
        </button>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto px-[18px] [&>*:last-child]:border-b-0">
        <PriceCeiling
          fuel={fuel}
          prices={prices}
          value={filters.max}
          average={average}
          onChange={(max) => onChange({ max })}
        />
        <SegSection
          title="Distance"
          hint={located ? "from your location" : "from the map centre"}
          options={DISTANCE_OPTIONS}
          value={filters.km}
          onChange={(km) => onChange({ km })}
        />
        <SegSection
          title="Price updated"
          options={FRESH_CHOICES}
          value={filters.fresh}
          onChange={(fresh) => onChange({ fresh: fresh as MapFilters["fresh"] })}
        />
        <BrandSection fuel={fuel} pool={brandScope} filters={filters} onChange={onChange} />
        <div className="grid gap-2 py-3">
          <div className="flex items-baseline justify-between gap-2">
            <span className="caption">Also sells</span>
            <span className="text-[11px] text-ink-3">station must stock every fuel ticked</span>
          </div>
          <div className="flex flex-wrap gap-1.5">
            {others.map((f) => (
              <FilterChip key={f} on={filters.also.includes(f)} onClick={() => toggleAlso(f)}>
                {f}
              </FilterChip>
            ))}
          </div>
        </div>
      </div>

      <footer className="flex flex-wrap items-center justify-between gap-2 border-t border-line bg-surface px-[18px] py-3">
        <div className="flex items-center gap-2">
          <button type="button" className="btn btn-secondary btn-sm" onClick={onReset} disabled={count === 0}>
            Reset
          </button>
          <button type="button" className="btn btn-secondary btn-sm" onClick={onSavePreset} disabled={count === 0}>
            Save as preset
          </button>
        </div>
        <button type="button" className="btn btn-primary" onClick={onClose}>
          Show {shownCount} station{shownCount === 1 ? "" : "s"}
        </button>
      </footer>
    </div>
  );
}
