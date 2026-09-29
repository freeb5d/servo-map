"use client";

import type { RefObject } from "react";
import { Icon } from "@/components/ui/Icon";
import { cn } from "@/lib/utils";
import type { MapFilters, SortMode } from "@/lib/filters";
import { FilterChip } from "./FilterChip";
import type { Preset } from "./usePresets";

interface QuickFiltersProps {
  filters: MapFilters;
  onChange: (update: Partial<MapFilters>) => void;
  activeCount: number;
  panelOpen: boolean;
  onTogglePanel: () => void;
  triggerRef: RefObject<HTMLButtonElement | null>;
  presets: Preset[];
  onApplyPreset: (preset: Preset) => void;
  onRemovePreset: (key: string) => void;
  /** Phones only: the top bar has no locate control there, so it lives here. */
  onLocate: () => void;
  locating: boolean;
}

const SORTS: { id: SortMode; label: string }[] = [
  { id: "price", label: "Cheapest" },
  { id: "distance", label: "Nearest" },
];

/** Sort switch, the Filters button, saved presets and the one-tap chips under the verdict. */
export function QuickFilters({
  filters,
  onChange,
  activeCount,
  panelOpen,
  onTogglePanel,
  triggerRef,
  presets,
  onApplyPreset,
  onRemovePreset,
  onLocate,
  locating,
}: QuickFiltersProps) {
  return (
    <div className="grid gap-2 border-b border-line-subtle px-5 py-2.5">
      <div className="flex items-center justify-between gap-2">
        <div role="group" aria-label="Sort stations" className="seg">
          {SORTS.map((s) => (
            <button
              key={s.id}
              type="button"
              aria-pressed={filters.sort === s.id}
              onClick={() => onChange({ sort: s.id })}
              className="seg-item"
            >
              {s.label}
            </button>
          ))}
        </div>
        <div className="flex items-center gap-1">
        <button
          type="button"
          className={cn("icon-btn md:hidden", locating && "animate-breathe")}
          aria-label="Use my location"
          onClick={onLocate}
          disabled={locating}
        >
          <Icon name="locate" />
        </button>
        <button
          ref={triggerRef}
          type="button"
          aria-haspopup="dialog"
          aria-expanded={panelOpen}
          onClick={onTogglePanel}
          className={cn("btn btn-sm", panelOpen ? "btn-primary" : "btn-secondary")}
        >
          <Icon name="filter" size={14} />
          Filters
          {activeCount > 0 && (
            <span
              className={cn(
                "inline-grid h-4 min-w-4 place-items-center rounded-1 px-[3px] text-[10.5px]",
                panelOpen ? "bg-surface text-ink" : "bg-accent text-on-accent",
              )}
            >
              {activeCount}
            </span>
          )}
        </button>
        </div>
      </div>

      {presets.length > 0 && (
        <div className="flex flex-wrap gap-1.5" role="group" aria-label="Saved filter presets">
          {presets.map((p) => (
            <span
              key={p.key}
              className="inline-flex h-6 items-center rounded-1 border border-dashed border-line bg-surface text-small text-ink-2"
            >
              <button
                type="button"
                onClick={() => onApplyPreset(p)}
                className="h-full px-2 hover:text-ink"
              >
                {p.label}
              </button>
              <button
                type="button"
                onClick={() => onRemovePreset(p.key)}
                aria-label={`Remove preset ${p.label}`}
                className="grid h-full w-5 place-items-center text-ink-3 hover:text-ink"
              >
                <Icon name="close" size={10} />
              </button>
            </span>
          ))}
        </div>
      )}

      <div className="flex flex-wrap gap-1.5" role="group" aria-label="Quick filters">
        <FilterChip
          on={filters.km === 5}
          onClick={() => onChange({ km: filters.km === 5 ? undefined : 5 })}
        >
          ≤ 5 km
        </FilterChip>
        <FilterChip
          on={filters.tier === "cheap"}
          onClick={() => onChange({ tier: filters.tier ? undefined : "cheap" })}
        >
          Cheap only
        </FilterChip>
        <FilterChip
          on={filters.fresh === 6}
          onClick={() => onChange({ fresh: filters.fresh === 6 ? undefined : 6 })}
        >
          Updated &lt; 6 h
        </FilterChip>
        <FilterChip
          on={filters.group === "major"}
          onClick={() => onChange({ group: filters.group === "major" ? undefined : "major" })}
        >
          Majors
        </FilterChip>
        <FilterChip
          on={filters.noMembers}
          onClick={() => onChange({ noMembers: !filters.noMembers })}
        >
          No members-only
        </FilterChip>
      </div>
    </div>
  );
}
