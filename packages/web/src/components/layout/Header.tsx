"use client";

import Link from "next/link";
import { ThemeToggle } from "./ThemeToggle";
import { BrandMark } from "@/components/brand/BrandMark";
import { FUEL_TYPES, type FuelType } from "@servo-map/shared";
import { cn } from "@/lib/utils";

interface HeaderProps {
  selectedFuel: FuelType;
  onFuelChange: (fuel: FuelType) => void;
}

export function Header({ selectedFuel, onFuelChange }: HeaderProps) {
  return (
    <header className="fixed top-0 left-0 right-0 z-50 pointer-events-none">
      <div className="flex items-center justify-between px-4 py-3 md:px-6">
        {/* Logo */}
        <div className="pointer-events-auto animate-fade-in">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-8 h-8 rounded-lg overflow-hidden border border-border shadow-card transition-transform duration-[var(--duration-normal)] ease-[var(--ease-out-expo)] group-hover:scale-110">
              <BrandMark
                size={32}
                tile="var(--color-surface)"
                ink="var(--color-text)"
                accent="var(--color-terracotta-dim)"
              />
            </div>
            <span className="font-display font-bold text-lg tracking-tight text-text hidden sm:block">
              ServoMap
            </span>
          </Link>
        </div>

        {/* 燃油类型快捷切换 */}
        <div className="pointer-events-auto animate-fade-in delay-1">
          <div
            role="group"
            aria-label="Fuel type"
            className="glass rounded-[var(--radius-pill)] border border-border-subtle shadow-float p-1 flex gap-0.5"
          >
            {FUEL_TYPES.map((fuel) => (
              <button
                key={fuel}
                type="button"
                onClick={() => onFuelChange(fuel)}
                aria-pressed={selectedFuel === fuel}
                aria-label={`Show ${fuel} prices`}
                className={cn(
                  "px-3 py-1.5 rounded-[var(--radius-pill)] text-xs font-semibold transition-all duration-[var(--duration-fast)]",
                  selectedFuel === fuel
                    ? "bg-ochre text-bg shadow-sm"
                    : "text-text-secondary hover:text-text hover:bg-surface-hover",
                )}
              >
                {fuel}
              </button>
            ))}
          </div>
        </div>

        {/* Theme toggle */}
        <div className="pointer-events-auto animate-fade-in delay-2">
          <ThemeToggle />
        </div>
      </div>
    </header>
  );
}
