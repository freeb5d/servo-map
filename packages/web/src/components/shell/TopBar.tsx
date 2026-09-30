"use client";

import Link from "next/link";
import { BrandMark } from "@/components/brand/BrandMark";
import { FUEL_TYPES, type FuelType } from "@servo-map/shared";
import { ThemeToggle } from "@/components/layout/ThemeToggle";
import { Icon } from "@/components/ui/Icon";
import { cn } from "@/lib/utils";
import { SearchField } from "./SearchField";
import { SECTIONS, type Section } from "./nav";

interface TopBarProps {
  /** Highlighted section; null on pages outside the three sections (SEO pages). */
  active: Section | null;
  /** Fuel switch is shown only when the page reacts to it. */
  fuel?: FuelType;
  onFuelChange?: (fuel: FuelType) => void;
  initialQuery?: string;
  onLocate?: () => void;
  locating?: boolean;
}

/**
 * The fixed paper top bar (v2): logo, search, fuel, sections, theme. On phones the
 * sections move to MobileTabs and the bar keeps only search and fuel.
 */
export function TopBar({
  active,
  fuel,
  onFuelChange,
  initialQuery,
  onLocate,
  locating,
}: TopBarProps) {
  const fuelSwitch = fuel && onFuelChange && (
    <div role="group" aria-label="Fuel type" className="seg max-md:flex max-md:justify-between">
      {FUEL_TYPES.map((f) => (
        <button
          key={f}
          type="button"
          aria-pressed={fuel === f}
          aria-label={`Show ${f} prices`}
          onClick={() => onFuelChange(f)}
          className="seg-item"
        >
          {f}
        </button>
      ))}
    </div>
  );

  return (
    <header className="relative z-40 bg-surface border-b border-line">
      <div className="flex items-center gap-5 h-14 px-5 max-md:hidden">
        <Logo />
        <SearchField initialQuery={initialQuery} className="flex-1 max-w-[400px]" />
        {fuelSwitch}
        <nav aria-label="Sections" className="flex gap-1">
          {SECTIONS.map((s) => (
            <Link
              key={s.id}
              href={s.href}
              aria-current={active === s.id ? "page" : undefined}
              className={cn(
                "px-3 py-1.5 text-body border-b-[1.5px] transition-colors duration-(--duration-fast)",
                active === s.id
                  ? "text-ink border-ink font-medium"
                  : "text-ink-2 border-transparent hover:text-ink",
              )}
            >
              {s.label}
            </Link>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-1">
          {onLocate && (
            <button
              type="button"
              className={cn("icon-btn", locating && "animate-breathe")}
              aria-label="Use my location"
              onClick={onLocate}
              disabled={locating}
            >
              <Icon name="locate" />
            </button>
          )}
          <ThemeToggle />
        </div>
      </div>

      <div className="md:hidden grid gap-2 px-3 pt-3 pb-2.5">
        <div className="flex items-center gap-2">
          <Logo compact />
          <SearchField initialQuery={initialQuery} className="flex-1" />
          <ThemeToggle />
        </div>
        {fuelSwitch}
      </div>
    </header>
  );
}

function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <Link href="/" className="flex items-center gap-2.5 shrink-0" aria-label="ServoMap home">
      {/* The tile takes the header's surface so the mark sits flush; ink and needle follow the theme. */}
      <BrandMark size={24} tile="var(--color-surface)" ink="var(--color-ink)" accent="var(--color-brand)" />
      {!compact && (
        <span className="font-display text-lead font-semibold text-ink">ServoMap</span>
      )}
    </Link>
  );
}
