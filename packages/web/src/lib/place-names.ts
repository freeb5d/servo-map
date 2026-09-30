import type { Station } from "@servo-map/shared";

// Station names, addresses and suburbs arrive title-cased from the worker's ingest adapters
// (packages/worker/src/utils/place-names.ts); only the address line is composed here.

/** Full address line; skips the suburb and postcode when the feed already put them in the address. */
export function formatAddress(station: Pick<Station, "address" | "suburb" | "state" | "postcode">): string {
  if (station.address.toLowerCase().includes(station.suburb.toLowerCase())) return station.address;
  return `${station.address}, ${station.suburb} ${station.state.toUpperCase()} ${station.postcode}`;
}
