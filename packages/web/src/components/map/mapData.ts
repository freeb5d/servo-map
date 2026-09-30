import { brandFamily, type FuelType, type StationWithDistance } from "@servo-map/shared";
import { computePriceRange, formatPriceCents, getFuelPrice, type PriceRange } from "@/lib/utils";

/** Properties carried by each station feature; tier is 0 cheap / 1 fair / 2 pricey. */
export interface StationFeatureProps {
  id: string;
  brand: string;
  /** Brand family id; the tag draws that family's tile (brandImages.ts). */
  family: string;
  /** Selected fuel price in cents; clusters aggregate its minimum. */
  price: number;
  tier: number;
  label: string;
}

/**
 * Builds the map's GeoJSON. Stations without a price for the fuel are skipped. Tiers reuse the
 * shared range so the map agrees with the ledger; without one they are computed locally.
 */
export function buildStationCollection(
  stations: StationWithDistance[],
  fuel: FuelType,
  range: PriceRange | undefined,
): GeoJSON.FeatureCollection<GeoJSON.Point, StationFeatureProps> {
  const priced = stations.flatMap((station) => {
    const fp = getFuelPrice(station.prices, fuel);
    return fp ? [{ station, price: fp.price }] : [];
  });
  const effective = range ?? computePriceRange(priced.map((p) => p.price));

  return {
    type: "FeatureCollection",
    features: priced.map(({ station, price }) => ({
      type: "Feature" as const,
      geometry: { type: "Point" as const, coordinates: [station.lng, station.lat] },
      properties: {
        id: station.id,
        brand: station.brand,
        family: brandFamily(station.brand).id,
        price,
        tier: price <= effective.cheapBelow ? 0 : price <= effective.midBelow ? 1 : 2,
        label: formatPriceCents(price),
      },
    })),
  };
}

type StationCollection = GeoJSON.FeatureCollection<GeoJSON.Point, StationFeatureProps>;

/**
 * Takes the cheapest station out of the clustered collection. Its tag has its own unclustered
 * source, so it stays on the map at every zoom instead of disappearing into a cluster.
 */
export function splitCheapest(
  collection: StationCollection,
  cheapestId: string | null,
): { rest: StationCollection; cheapest: StationCollection } {
  const isCheapest = (f: StationCollection["features"][number]) => f.properties.id === cheapestId;
  return {
    rest: { type: "FeatureCollection", features: collection.features.filter((f) => !isCheapest(f)) },
    cheapest: { type: "FeatureCollection", features: collection.features.filter(isCheapest) },
  };
}
