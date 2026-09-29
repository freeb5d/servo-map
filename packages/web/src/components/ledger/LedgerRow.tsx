"use client";

import type { FuelType, StationWithDistance } from "@servo-map/shared";
import { BrandSeal } from "@/components/ui/BrandSeal";
import { FavouriteButton } from "@/components/stations/FavouriteButton";
import { usePriceRange } from "@/providers/PriceRangeProvider";
import { cn, formatDistance, formatPriceCents, getFuelPrice, priceTier, timeAgo } from "@/lib/utils";
import { TierLabel } from "@/components/ui/TierLabel";

interface LedgerRowProps {
  station: StationWithDistance;
  fuel: FuelType;
  /** 1-based rank; null for stations with an old price, which are not ranked. */
  rank: number | null;
  active: boolean;
  favourite: boolean;
  onSelect: (station: StationWithDistance) => void;
  onToggleFavourite: (id: string) => void;
}

/** One station in the ledger. The bookmark sits beside the row button, not inside it. */
export function LedgerRow({
  station,
  fuel,
  rank,
  active,
  favourite,
  onSelect,
  onToggleFavourite,
}: LedgerRowProps) {
  const range = usePriceRange();
  const fp = getFuelPrice(station.prices, fuel);
  if (!fp) return null;

  const where =
    station.distance !== undefined
      ? `${station.suburb}, ${formatDistance(station.distance)}`
      : station.suburb;

  return (
    <li className="group relative border-b border-line-subtle">
      <button
        type="button"
        id={`row-${station.id}`}
        onClick={() => onSelect(station)}
        aria-current={active ? "true" : undefined}
        className={cn(
          "grid w-full grid-cols-[18px_30px_minmax(0,1fr)_auto] items-center gap-2.5 py-[11px] pl-5 pr-10 text-left outline-none transition-colors duration-(--duration-fast) hover:bg-wash/55 focus-visible:outline-[1.5px] focus-visible:-outline-offset-2 focus-visible:outline-accent",
          active && "bg-wash hover:bg-wash",
        )}
      >
        <span className="font-display text-[13px] tabular-nums text-ink-3">{rank ?? "–"}</span>
        <BrandSeal brand={station.brand} />
        <span className="min-w-0">
          <span className="block truncate font-medium text-ink">{station.name}</span>
          <span className="block truncate text-[11.5px] text-ink-3">{where}</span>
        </span>
        <span className="grid justify-items-end gap-0.5">
          <span className="font-display text-[19px] leading-[1.2] font-semibold tabular-nums text-ink">
            {formatPriceCents(fp.price)}
            <span className="ml-0.5 font-body text-[0.45em] font-normal text-ink-3">¢/L</span>
          </span>
          {rank === null ? (
            <span className="text-[10.5px] text-price-expensive">{timeAgo(fp.updated_at)}</span>
          ) : (
            <TierLabel tier={priceTier(fp.price, range)} />
          )}
        </span>
      </button>
      <FavouriteButton
        active={favourite}
        onToggle={() => onToggleFavourite(station.id)}
        className="absolute right-1.5 top-1/2 -translate-y-1/2 opacity-0 transition-opacity group-hover:opacity-100 focus-visible:opacity-100 aria-pressed:opacity-100 [@media(hover:none)]:opacity-100"
      />
    </li>
  );
}
