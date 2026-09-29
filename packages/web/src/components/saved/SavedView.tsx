"use client";

import Link from "next/link";
import type { FuelType, Station } from "@servo-map/shared";
import { MobileTabs } from "@/components/shell/MobileTabs";
import { TopBar } from "@/components/shell/TopBar";
import { ModuleNote } from "@/components/trends/Card";
import { useFavourites } from "@/hooks/useFavourites";
import { useFuelPreference } from "@/hooks/useFuelPreference";
import { rankByPrice } from "@/lib/saved";
import { computePriceRange, getFuelPrice, priceTier, type PriceRange } from "@/lib/utils";
import { SavedRow, UnavailableRow } from "./SavedRow";
import { useSavedStations } from "./useSavedStations";

/** Tiers compare saved stations with each other, which says nothing with fewer than three. */
const MIN_FOR_TIERS = 3;

/** The /saved page: bookmarked stations ranked by today's price, with change since the last visit. */
export function SavedView() {
  const { favouriteIds, toggle, ready } = useFavourites();
  const [fuel, setFuel] = useFuelPreference();
  const { entries, baseline, loading } = useSavedStations(favouriteIds, ready);

  const loaded = favouriteIds.flatMap((id) => {
    const entry = entries[id];
    return entry?.status === "ok" ? [{ station: entry.station }] : [];
  });
  const ranked = rankByPrice(loaded, fuel).map((r) => r.station);
  const unavailable = favouriteIds.filter((id) => entries[id] && entries[id].status !== "ok");
  const prices = ranked.flatMap((s) => getFuelPrice(s.prices, fuel)?.price ?? []);
  const range = prices.length >= MIN_FOR_TIERS ? computePriceRange(prices) : undefined;

  return (
    <div className="min-h-screen bg-bg pb-[calc(72px+env(safe-area-inset-bottom))] md:pb-0">
      <TopBar active="saved" fuel={fuel} onFuelChange={setFuel} />
      <main className="mx-auto grid max-w-3xl gap-4 px-3 pb-12 pt-6 md:px-6 md:pt-8">
        <header className="grid gap-1">
          <h1 className="font-display text-[24px] font-semibold leading-tight md:text-display md:font-medium">Saved</h1>
          {favouriteIds.length > 0 && (
            <p className="text-body text-ink-2">
              {favouriteIds.length} station{favouriteIds.length === 1 ? "" : "s"}, cheapest {fuel} first.
            </p>
          )}
        </header>

        {!ready || loading ? (
          <ModuleNote busy>Loading your saved stations.</ModuleNote>
        ) : favouriteIds.length === 0 ? (
          <EmptyState />
        ) : (
          <ul className="overflow-hidden rounded-3 border border-line-subtle bg-surface max-md:-mx-3 max-md:rounded-none max-md:border-x-0">
            {ranked.map((station, i) => (
              <SavedRow
                key={station.id}
                rank={i + 1}
                station={station}
                fuel={fuel}
                previous={baseline[station.id]?.[fuel]}
                tier={tierFor(station, fuel, range)}
                onRemove={() => toggle(station.id)}
              />
            ))}
            {unavailable.map((id) => (
              <UnavailableRow key={id} id={id} status={entries[id].status as "missing" | "error"} onRemove={() => toggle(id)} />
            ))}
          </ul>
        )}

        <p className="text-small text-ink-3">Saved stations stay on this device.</p>
      </main>
      <MobileTabs active="saved" />
    </div>
  );
}

function tierFor(station: Station, fuel: FuelType, range: PriceRange | undefined) {
  const price = getFuelPrice(station.prices, fuel);
  return range && price ? priceTier(price.price, range) : null;
}

function EmptyState() {
  return (
    <div className="grid justify-items-start gap-4 rounded-3 border border-line-subtle bg-surface px-5 py-6">
      <p className="max-w-[36em] text-body text-ink-2">
        You haven&rsquo;t saved a station yet. Tap the bookmark on any station to keep its price here.
      </p>
      <Link href="/" className="btn btn-primary">
        Open the map
      </Link>
    </div>
  );
}
