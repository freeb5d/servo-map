"use client";

import { useCallback, useEffect, useState } from "react";
import type { AustralianState, StationWithDistance } from "@servo-map/shared";
import { getStations } from "@/lib/api";
import { useGeolocation } from "@/hooks/useGeolocation";

/** Radius for every "near you" module, in km. */
export const NEAR_RADIUS_KM = 10;

interface Place {
  lat: number;
  lng: number;
  /** How the place reads in copy: "Sydney CBD", "your location". */
  label: string;
}

/** Where "near you" is centred before the viewer shares a location; nothing here prompts. */
const STATE_CENTRES: Record<AustralianState, Place> = {
  nsw: { lat: -33.8688, lng: 151.2093, label: "Sydney CBD" },
  qld: { lat: -27.4698, lng: 153.0251, label: "Brisbane CBD" },
  vic: { lat: -37.8136, lng: 144.9631, label: "Melbourne CBD" },
  wa: { lat: -31.9505, lng: 115.8605, label: "Perth CBD" },
  sa: { lat: -34.9285, lng: 138.6007, label: "Adelaide CBD" },
  tas: { lat: -42.8821, lng: 147.3272, label: "Hobart CBD" },
  act: { lat: -35.2809, lng: 149.13, label: "Canberra city" },
  nt: { lat: -12.4634, lng: 130.8456, label: "Darwin CBD" },
};

type Loaded = { key: string; stations: StationWithDistance[] } | { key: string; failed: true };

export interface NearYou {
  place: Place;
  stations: StationWithDistance[];
  status: "loading" | "ready" | "error";
  retry: () => void;
  /** Switches to the browser location; asks for permission only when called. */
  locateMe: () => void;
  locating: boolean;
  locationError: string | null;
}

/** Stations within NEAR_RADIUS_KM of the state's centre, or of the viewer once they opt in. */
export function useNearYou(state: AustralianState): NearYou {
  const [mine, setMine] = useState<Place | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [loaded, setLoaded] = useState<Loaded | null>(null);
  const geo = useGeolocation();
  const { locate } = geo;

  const place = mine ?? STATE_CENTRES[state];
  const key = `${place.lat},${place.lng},${attempt}`;

  useEffect(() => {
    let cancelled = false;
    getStations({ lat: place.lat, lng: place.lng, radius: NEAR_RADIUS_KM, limit: 500 })
      .then(({ data }) => {
        if (!cancelled) setLoaded({ key, stations: data });
      })
      .catch(() => {
        if (!cancelled) setLoaded({ key, failed: true });
      });
    return () => {
      cancelled = true;
    };
  }, [key, place.lat, place.lng]);

  const retry = useCallback(() => setAttempt((n) => n + 1), []);
  const locateMe = useCallback(() => {
    locate(({ lat, lng }) => setMine({ lat, lng, label: "your location" }));
  }, [locate]);

  const current = loaded?.key === key ? loaded : null;
  const status = !current ? "loading" : "failed" in current ? "error" : "ready";
  return {
    place,
    stations: current && "stations" in current ? current.stations : [],
    status,
    retry,
    locateMe,
    locating: geo.loading,
    locationError: geo.error,
  };
}
