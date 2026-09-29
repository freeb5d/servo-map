"use client";

import { useMemo } from "react";
import {
  BRAND_FAMILIES,
  BRAND_GROUP_LABELS,
  type BrandGroup,
  type FuelType,
  type StationWithDistance,
} from "@servo-map/shared";
import { brandStats } from "@/lib/aggregate";
import type { BrandMode, MapFilters } from "@/lib/filters";
import { BrandSeal } from "@/components/ui/BrandSeal";
import { Icon } from "@/components/ui/Icon";
import { formatPriceCents } from "@/lib/utils";

interface BrandSectionProps {
  fuel: FuelType;
  /** Stations the non-brand filters leave in; counts and averages come from these. */
  pool: StationWithDistance[];
  filters: MapFilters;
  onChange: (update: Partial<MapFilters>) => void;
}

const GROUP_ORDER = Object.keys(BRAND_GROUP_LABELS) as BrandGroup[];
const MODES: { id: BrandMode; label: string }[] = [
  { id: "only", label: "Only these" },
  { id: "hide", label: "Hide these" },
];

/** Brand families grouped as majors / value / members / independent, with include or exclude mode. */
export function BrandSection({ fuel, pool, filters, onChange }: BrandSectionProps) {
  const stats = useMemo(() => new Map(brandStats(pool, fuel).map((s) => [s.family.id, s] as const)), [pool, fuel]);
  const selected = new Set(filters.brands);

  const groups = GROUP_ORDER.map((group) => ({
    group,
    families: BRAND_FAMILIES.filter(
      (f) => f.group === group && (stats.has(f.id) || selected.has(f.id)),
    ),
  })).filter((g) => g.families.length > 0);

  const setBrands = (ids: Iterable<string>) => onChange({ brands: [...new Set(ids)] });
  const toggle = (id: string) => {
    const next = new Set(selected);
    if (!next.delete(id)) next.add(id);
    setBrands(next);
  };
  const toggleGroup = (ids: string[]) => {
    const next = new Set(selected);
    const all = ids.every((id) => next.has(id));
    for (const id of ids) {
      if (all) next.delete(id);
      else next.add(id);
    }
    setBrands(next);
  };

  return (
    <div className="grid gap-1 border-b border-line-subtle py-3">
      <div className="flex items-center justify-between gap-2">
        <span className="caption">Brands, average {fuel} today</span>
        <div role="group" aria-label="Brand filter mode" className="seg">
          {MODES.map((m) => (
            <button
              key={m.id}
              type="button"
              aria-pressed={filters.mode === m.id}
              onClick={() => onChange({ mode: m.id })}
              className="seg-item"
            >
              {m.label}
            </button>
          ))}
        </div>
      </div>

      {groups.map(({ group, families }) => {
        const ids = families.map((f) => f.id);
        const all = ids.every((id) => selected.has(id));
        return (
          <div key={group}>
            <div className="flex items-center justify-between pt-1.5 pb-0.5">
              <span className="caption">{BRAND_GROUP_LABELS[group]}</span>
              <button type="button" onClick={() => toggleGroup(ids)} className="text-[11px] text-ink-3 underline-offset-4 hover:text-ink hover:underline">
                {all ? "Clear" : "Select all"}
              </button>
            </div>
            <ul className="grid gap-x-4 sm:grid-cols-2">
              {families.map((f) => {
                const stat = stats.get(f.id);
                return (
                  <li key={f.id}>
                    <label className="grid cursor-pointer grid-cols-[14px_34px_1fr_auto] items-center gap-2 py-[5px] text-small">
                      <input
                        type="checkbox"
                        checked={selected.has(f.id)}
                        onChange={() => toggle(f.id)}
                        className="peer sr-only"
                      />
                      <span className="grid size-3.5 place-items-center rounded-1 border border-line text-transparent peer-checked:border-accent peer-checked:bg-accent peer-checked:text-on-accent peer-focus-visible:outline-[1.5px] peer-focus-visible:outline-offset-2 peer-focus-visible:outline-accent">
                        <Icon name="check" size={10} />
                      </span>
                      <BrandSeal brand={f.name} />
                      <span className="min-w-0 truncate">
                        {f.name} <span className="text-[11px] text-ink-3">{stat?.count ?? 0}</span>
                      </span>
                      <span className="font-display text-small font-semibold tabular-nums">
                        {stat ? formatPriceCents(stat.avg) : "–"}
                      </span>
                    </label>
                  </li>
                );
              })}
            </ul>
          </div>
        );
      })}
    </div>
  );
}
