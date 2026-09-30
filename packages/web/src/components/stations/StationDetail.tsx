"use client";

import { useMemo } from "react";
import {
  FUEL_TYPES,
  brandFamily,
  type FuelType,
  type StationWithDistance,
} from "@servo-map/shared";
import { BrandSeal } from "@/components/ui/BrandSeal";
import { Icon } from "@/components/ui/Icon";
import { TierLabel } from "@/components/ui/TierLabel";
import { SourceNotice } from "@/components/doc/SourceNotice";
import { sourceLabel } from "@/components/ledger/stationMeta";
import { priceSpread, fillCost } from "@/lib/aggregate";
import { usePriceRange } from "@/providers/PriceRangeProvider";
import {
  cn,
  formatDistance,
  formatPriceCents,
  getFuelPrice,
  haversineKm,
  priceTier,
  timeAgo,
} from "@/lib/utils";
import { ShareButton } from "./ShareButton";
import { formatAddress } from "@/lib/place-names";

interface StationDetailProps {
  station: StationWithDistance;
  selectedFuel: FuelType;
  /** Loaded stations, for the area average and "also nearby". */
  nearby: StationWithDistance[];
  isFavourite: boolean;
  onToggleFavourite: () => void;
  onSelectStation: (station: StationWithDistance) => void;
  onClose: () => void;
}

const FILL_LITRES = 50;
const NEARBY_KM = 3;

/** Cheapest other stations within NEARBY_KM of this one, by the selected fuel. */
function cheapestNearby(
  station: StationWithDistance,
  stations: StationWithDistance[],
  fuel: FuelType,
): { station: StationWithDistance; km: number; price: number }[] {
  return stations
    .filter((s) => s.id !== station.id)
    .map((s) => ({
      station: s,
      km: haversineKm(station.lat, station.lng, s.lat, s.lng),
      price: getFuelPrice(s.prices, fuel)?.price ?? Infinity,
    }))
    .filter((n) => n.km <= NEARBY_KM && Number.isFinite(n.price))
    .sort((a, b) => a.price - b.price)
    .slice(0, 2);
}

/** Station detail: price and tier, what a fill costs against the area, every fuel, actions, neighbours. */
export function StationDetail({
  station,
  selectedFuel,
  nearby,
  isFavourite,
  onToggleFavourite,
  onSelectStation,
  onClose,
}: StationDetailProps) {
  const range = usePriceRange();
  const family = brandFamily(station.brand);
  const selected = getFuelPrice(station.prices, selectedFuel);
  const spread = useMemo(() => priceSpread(nearby, selectedFuel), [nearby, selectedFuel]);
  const neighbours = useMemo(
    () => cheapestNearby(station, nearby, selectedFuel),
    [station, nearby, selectedFuel],
  );
  const fuels = [...station.prices].sort(
    (a, b) => FUEL_TYPES.indexOf(a.fuel) - FUEL_TYPES.indexOf(b.fuel),
  );
  const directionsUrl = `https://www.google.com/maps/dir/?api=1&destination=${station.lat},${station.lng}`;

  return (
    <div className="grid content-start gap-3.5 p-5 max-md:pt-2">
      <div className="flex items-start justify-between gap-2">
        <div className="grid min-w-0 gap-1.5">
          <div className="flex items-center gap-2">
            <BrandSeal brand={station.brand} size="lg" />
            <span className="caption">
              {family.name}
            </span>
          </div>
          <h2 className="font-display text-[23px] leading-[1.3] font-semibold text-ink">{station.name}</h2>
          <p className="text-small text-ink-3">
            {formatAddress(station)}
            {station.distance !== undefined && `, ${formatDistance(station.distance)}`}
          </p>
        </div>
        <button type="button" onClick={onClose} className="icon-btn" aria-label="Close station details">
          <Icon name="close" />
        </button>
      </div>

      {selected && (
        <div className="flex items-end justify-between">
          <span className="font-display text-[40px] md:text-price-xl leading-none font-semibold tabular-nums text-ink">
            {formatPriceCents(selected.price)}
            <span className="ml-0.5 font-body text-[0.3em] font-normal text-ink-3">¢/L {selectedFuel}</span>
          </span>
          <TierLabel tier={priceTier(selected.price, range)} />
        </div>
      )}

      {selected && spread && <FillBox price={selected.price} average={spread.avg} />}

      <table className="w-full border-collapse text-body">
        <caption className="sr-only">Fuel prices at this station</caption>
        <tbody>
          {fuels.map((fp) => (
            <tr key={fp.fuel} className="border-b border-line-subtle last:border-b-0">
              <th
                scope="row"
                className={cn("py-[7px] text-left font-normal text-ink", fp.fuel === selectedFuel && "font-bold")}
              >
                {fp.fuel}
              </th>
              <td className="py-[7px] text-right font-display text-[16px] font-semibold tabular-nums text-ink">
                {formatPriceCents(fp.price)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <div className="grid grid-cols-[1fr_auto_auto] gap-2">
        <a href={directionsUrl} target="_blank" rel="noopener noreferrer" className="btn btn-primary">
          <Icon name="directions" />
          Directions
        </a>
        <button
          type="button"
          onClick={onToggleFavourite}
          aria-pressed={isFavourite}
          aria-label={isFavourite ? "Remove from saved" : "Save station"}
          className="btn btn-secondary px-3"
        >
          <Icon name="bookmark" size={18} filled={isFavourite} />
        </button>
        <ShareButton
          iconOnly
          title={`${station.brand} ${station.name} — ServoMap`}
          path={`/station/${station.id}`}
          className="px-3"
        />
      </div>

      {neighbours.length > 0 && (
        <div>
          <h3 className="caption">Also nearby</h3>
          <ul>
            {neighbours.map(({ station: n, km, price }) => (
              <li key={n.id} className="border-b border-line-subtle last:border-b-0">
                <button
                  type="button"
                  onClick={() => onSelectStation(n)}
                  className="flex w-full items-center justify-between gap-2 py-[7px] text-left text-body hover:text-ink"
                >
                  <span className="flex min-w-0 items-center gap-2">
                    <BrandSeal brand={n.brand} />
                    <span className="truncate">
                      {n.name}, {formatDistance(km)}
                    </span>
                  </span>
                  <span className="font-display text-[14px] font-semibold tabular-nums">
                    {formatPriceCents(price)}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}

      {selected && (
        <p className="text-[10.5px] text-ink-3">
          Price reported {timeAgo(selected.updated_at)} via {sourceLabel(station.state)}
        </p>
      )}
      <SourceNotice state={station.state} className="text-[10.5px] leading-snug" />
    </div>
  );
}

function FillBox({ price, average }: { price: number; average: number }) {
  const cost = fillCost(price, FILL_LITRES);
  const diff = fillCost(Math.abs(average - price), FILL_LITRES);
  return (
    <div className="rounded-3 border border-line-subtle bg-bg px-[13px] py-[11px] text-body text-ink-2">
      A {FILL_LITRES} L fill here costs <b className="text-ink">${cost.toFixed(2)}</b>
      {diff < 0.005 ? (
        <>, in line with the area average of {formatPriceCents(average)}.</>
      ) : (
        <>
          , <b className="text-ink">${diff.toFixed(2)}</b> {price < average ? "less" : "more"} than the area
          average of {formatPriceCents(average)}.
        </>
      )}
    </div>
  );
}
