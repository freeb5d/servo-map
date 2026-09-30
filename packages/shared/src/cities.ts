import type { AustralianState } from "./states";

/** A city the Trends tab compares: stations within `radiusKm` of its centre count as the city. */
export interface City {
  /** Stable kebab-case id, used as the API key and on clients. */
  id: string;
  name: string;
  /** The state the city's centre is in; stations are matched by distance, not by state. */
  state: AustralianState;
  lat: number;
  lng: number;
  radiusKm: number;
}

/**
 * The cities compared on Trends (decision 0008). Centres are each city's CBD or main centre;
 * radii are kept small enough that no two cities share a station.
 */
export const CITIES: readonly City[] = [
  { id: "sydney", name: "Sydney", state: "nsw", lat: -33.8688, lng: 151.2093, radiusKm: 20 },
  { id: "newcastle", name: "Newcastle", state: "nsw", lat: -32.9267, lng: 151.7789, radiusKm: 20 },
  { id: "wollongong", name: "Wollongong", state: "nsw", lat: -34.4278, lng: 150.8931, radiusKm: 20 },
  { id: "central-coast", name: "Central Coast", state: "nsw", lat: -33.425, lng: 151.342, radiusKm: 20 },
  { id: "canberra", name: "Canberra", state: "act", lat: -35.2809, lng: 149.13, radiusKm: 20 },
  { id: "perth", name: "Perth", state: "wa", lat: -31.9523, lng: 115.8613, radiusKm: 20 },
  { id: "bunbury", name: "Bunbury", state: "wa", lat: -33.3271, lng: 115.6414, radiusKm: 20 },
  { id: "hobart", name: "Hobart", state: "tas", lat: -42.8821, lng: 147.3272, radiusKm: 20 },
  { id: "launceston", name: "Launceston", state: "tas", lat: -41.4332, lng: 147.1441, radiusKm: 20 },
];
