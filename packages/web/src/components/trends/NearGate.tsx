"use client";

import type { ReactNode } from "react";
import type { FuelType, StationWithDistance } from "@servo-map/shared";
import { getFuelPrice } from "@/lib/utils";
import { ModuleNote } from "./Card";
import { NEAR_RADIUS_KM, type NearYou } from "./useNearYou";

interface NearGateProps {
  near: NearYou;
  fuel: FuelType;
  children: (stations: StationWithDistance[]) => ReactNode;
}

/** Shared loading, error and empty states for every module fed by the nearby stations. */
export function NearGate({ near, fuel, children }: NearGateProps) {
  const where = `within ${NEAR_RADIUS_KM} km of ${near.place.label}`;
  if (near.status === "loading") {
    return <ModuleNote busy>Loading stations {where}.</ModuleNote>;
  }
  if (near.status === "error") {
    return (
      <ModuleNote
        action={
          <button type="button" className="btn btn-quiet btn-sm" onClick={near.retry}>
            Try again
          </button>
        }
      >
        Couldn&rsquo;t load stations {where}.
      </ModuleNote>
    );
  }
  const selling = near.stations.filter((s) => getFuelPrice(s.prices, fuel));
  if (selling.length === 0) {
    return <ModuleNote>No station {where} reports {fuel} right now.</ModuleNote>;
  }
  return <>{children(selling)}</>;
}
