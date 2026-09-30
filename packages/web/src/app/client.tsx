"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { StationWithDistance } from "@servo-map/shared";
import { TopBar } from "@/components/shell/TopBar";
import { MobileTabs } from "@/components/shell/MobileTabs";
import { MapView } from "@/components/map/MapView";
import { useMapViewport } from "@/components/map/useMapViewport";
import type { ViewBounds } from "@/components/map/viewArea";
import { Ledger } from "@/components/ledger/Ledger";
import { useNow } from "@/components/ledger/useNow";
import { cheapestRankedId } from "@/components/ledger/rank";
import { cheapestInView, headlineScope, stationsInView } from "@/components/ledger/inView";
import { centroid, dominantState } from "@/components/ledger/stationMeta";
import { FilterPanel } from "@/components/filters/FilterPanel";
import { QuickFilters } from "@/components/filters/QuickFilters";
import { useMapFilters } from "@/components/filters/useMapFilters";
import { usePresets, type Preset } from "@/components/filters/usePresets";
import { BottomSheet } from "@/components/layout/BottomSheet";
import { DetailShell } from "@/components/layout/DetailShell";
import { useIsDesktop } from "@/components/layout/useIsDesktop";
import { StationDetail } from "@/components/stations/StationDetail";
import { useFavourites } from "@/hooks/useFavourites";
import { useFuelPreference } from "@/hooks/useFuelPreference";
import { useGeolocation } from "@/hooks/useGeolocation";
import { useMetadata } from "@/hooks/useMetadata";
import { useStations } from "@/hooks/useStations";
import { useTrends } from "@/hooks/useTrends";
import { liveStates, latestUpdatedAt } from "@/lib/coverage";
import { DEFAULT_FILTERS, activeFilterCount, applyFilters } from "@/lib/filters";
import { PriceRangeProvider } from "@/providers/PriceRangeProvider";

// Height of MobileTabs (icon, label, padding) so phones reserve room for the fixed bar.
const TABS_SPACE = "max-md:pb-[calc(49px+max(6px,env(safe-area-inset-bottom)))]";

export default function HomeMap() {
  const [fuel, setFuel] = useFuelPreference();
  const [filters, setFilters] = useMapFilters();
  const { presets, save: savePreset, remove: removePreset } = usePresets();
  const { isFavourite, toggle: toggleFavourite } = useFavourites();
  const isDesktop = useIsDesktop();
  const now = useNow();

  const [active, setActive] = useState<StationWithDistance | null>(null);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const filtersButtonRef = useRef<HTMLButtonElement>(null);

  // A new search replaces the station on screen.
  const [seenQuery, setSeenQuery] = useState(filters.q);
  if (seenQuery !== filters.q) {
    setSeenQuery(filters.q);
    setActive(null);
  }

  // Panning away from a searched suburb goes back to browsing the map.
  const clearSearch = useCallback(
    () => setFilters((prev) => (prev.q ? { ...prev, q: "" } : prev)),
    [setFilters],
  );
  const viewport = useMapViewport(clearSearch);
  // What the map shows right now; the verdict and the list rank only these stations.
  const [view, setView] = useState<ViewBounds | null>(null);

  const geo = useGeolocation();
  const hasLocated = geo.lat != null && geo.lng != null;
  const userLocation = useMemo(
    () => (geo.lat != null && geo.lng != null ? { lat: geo.lat, lng: geo.lng } : null),
    [geo.lat, geo.lng],
  );

  const stationsOpts = useMemo(
    () => ({
      fuel,
      lat: filters.q ? null : viewport.center.lat,
      lng: filters.q ? null : viewport.center.lng,
      radius: viewport.radius,
      q: filters.q || undefined,
      limit: 500,
    }),
    [fuel, viewport.center.lat, viewport.center.lng, viewport.radius, filters.q],
  );
  const { stations: loaded, loading, noResults, error, total, refresh } = useStations(stationsOpts);

  // A settled, complete circle lets the map pan and zoom inside it without another request.
  const loadedComplete = !filters.q && !loading && !error && total <= loaded.length;
  const { setLoadedComplete } = viewport;
  useEffect(() => setLoadedComplete(loadedComplete), [loadedComplete, setLoadedComplete]);

  // Distances are measured from the viewer, else from what the map shows.
  const origin = useMemo(
    () => userLocation ?? (filters.q ? centroid(loaded) : null) ?? viewport.center,
    [userLocation, filters.q, loaded, viewport.center],
  );
  const stations = useMemo(
    () => applyFilters(loaded, filters, fuel, origin, now),
    [loaded, filters, fuel, origin, now],
  );
  const inView = useMemo(() => stationsInView(stations, view), [stations, view]);
  const cheapest = useMemo(() => cheapestInView(stations, view, fuel, now), [stations, view, fuel, now]);
  const cheapestId = useMemo(() => cheapestRankedId(inView, fuel, now), [inView, fuel, now]);
  const filterCount = activeFilterCount(filters);

  const { metadata } = useMetadata();
  const liveStateList = useMemo(() => liveStates(metadata), [metadata]);
  const updatedAt = useMemo(() => {
    const inView = new Set(loaded.map((s) => s.state));
    const visible = liveStateList.filter((s) => inView.has(s));
    return latestUpdatedAt(metadata, visible.length ? visible : liveStateList);
  }, [metadata, loaded, liveStateList]);
  const cycle = useTrends(dominantState(loaded), fuel);

  // No stations at all (not just none after filtering) means the area has no feed yet.
  const noCoverage = !filters.q && !loading && !error && loaded.length === 0;

  const stationById = useMemo(() => new Map(loaded.map((s) => [s.id, s] as const)), [loaded]);
  const activeStation = active ? (stationById.get(active.id) ?? active) : null;

  const closeDetail = useCallback(() => {
    if (active) document.getElementById(`row-${active.id}`)?.focus();
    setActive(null);
  }, [active]);

  const handleLocate = useCallback(() => {
    setFilters((prev) => ({ ...prev, q: "", sort: "distance" }));
    geo.locate(viewport.recenter);
  }, [geo, setFilters, viewport.recenter]);

  const resetFilters = useCallback(
    () => setFilters((prev) => ({ ...DEFAULT_FILTERS, q: prev.q, sort: prev.sort })),
    [setFilters],
  );
  const applyPreset = useCallback(
    (preset: Preset) =>
      setFilters((prev) => ({ ...preset.filters, q: prev.q, sort: prev.sort })),
    [setFilters],
  );

  const scope = headlineScope(filters.q, userLocation, view);
  const liveMessage = loading
    ? "Loading stations…"
    : error
      ? "Couldn’t load fuel prices."
      : noResults
        ? `No stations found for ${filters.q}.`
        : noCoverage
          ? "No live prices in this area yet."
          : inView.length > 0
            ? `Showing ${inView.length} station${inView.length !== 1 ? "s" : ""} in view.`
            : "";

  const ledger = (
    <Ledger
      fuel={fuel}
      sort={filters.sort}
      stations={inView}
      matched={stations}
      cheapest={cheapest}
      loadedCount={loaded.length}
      loading={loading}
      error={error}
      onRetry={refresh}
      searchMiss={noResults ? filters.q : null}
      onClearSearch={clearSearch}
      noCoverage={noCoverage}
      liveStates={liveStateList}
      filterCount={filterCount}
      onResetFilters={resetFilters}
      scope={scope}
      cycle={cycle}
      updatedAt={updatedAt}
      now={now}
      activeId={activeStation?.id ?? null}
      onSelect={setActive}
      isFavourite={isFavourite}
      onToggleFavourite={toggleFavourite}
      tools={
        <QuickFilters
          filters={filters}
          onChange={setFilters}
          activeCount={filterCount}
          panelOpen={filtersOpen}
          onTogglePanel={() => setFiltersOpen((o) => !o)}
          triggerRef={filtersButtonRef}
          presets={presets}
          onApplyPreset={applyPreset}
          onRemovePreset={removePreset}
          onLocate={handleLocate}
          locating={geo.loading}
        />
      }
    />
  );

  const panel = filtersOpen && (
    <FilterPanel
      variant={isDesktop ? "popover" : "sheet"}
      fuel={fuel}
      filters={filters}
      onChange={setFilters}
      stations={loaded}
      origin={origin}
      located={hasLocated}
      now={now}
      shownCount={stations.length}
      onReset={resetFilters}
      onSavePreset={() => savePreset(filters)}
      onClose={() => setFiltersOpen(false)}
      triggerRef={filtersButtonRef}
    />
  );

  const detail = activeStation && (
    <DetailShell
      variant={isDesktop ? "drawer" : "sheet"}
      label="Station details"
      contentKey={activeStation.id}
      onClose={closeDetail}
    >
      <StationDetail
        station={activeStation}
        selectedFuel={fuel}
        nearby={loaded}
        isFavourite={isFavourite(activeStation.id)}
        onToggleFavourite={() => toggleFavourite(activeStation.id)}
        onSelectStation={setActive}
        onClose={closeDetail}
      />
    </DetailShell>
  );

  return (
    <PriceRangeProvider stations={loaded} selectedFuel={fuel}>
      <a href="#main-content" className="skip-link">
        Skip to content
      </a>

      {/* Polite status for screen readers: loading, empty states and the result count. */}
      <div aria-live="polite" role="status" className="sr-only">
        {liveMessage}
      </div>

      <div className={`flex h-dvh flex-col ${TABS_SPACE}`}>
        <TopBar
          active="map"
          fuel={fuel}
          onFuelChange={setFuel}
          initialQuery={filters.q}
          onLocate={handleLocate}
          locating={geo.loading}
        />

        <main id="main-content" tabIndex={-1} className="flex min-h-0 flex-1 outline-none">
          {isDesktop && (
            <aside aria-label="Stations" className="flex w-[400px] shrink-0 flex-col border-r border-line bg-surface">
              {ledger}
            </aside>
          )}

          <div className="relative min-w-0 flex-1">
            <MapView
              stations={stations}
              selectedFuel={fuel}
              activeStationId={activeStation?.id ?? null}
              cheapestStationId={cheapestId}
              userLocation={userLocation}
              searchQuery={filters.q}
              onStationClick={setActive}
              onMoveEnd={viewport.handleMoveEnd}
              onViewChange={setView}
            />
            {isDesktop && panel && (
              <div className="absolute bottom-2 left-2 top-2 z-20 grid w-[460px] max-w-[calc(100%-16px)] grid-rows-[minmax(0,1fr)]">
                {panel}
              </div>
            )}
            {!isDesktop && <BottomSheet>{ledger}</BottomSheet>}
            {!isDesktop && panel && (
              <div className="absolute inset-0 z-30 overflow-hidden rounded-t-[12px] border-t border-line bg-surface">
                {panel}
              </div>
            )}
            {!isDesktop && detail}
          </div>

          {isDesktop && detail}
        </main>
      </div>

      <MobileTabs active="map" />
    </PriceRangeProvider>
  );
}
