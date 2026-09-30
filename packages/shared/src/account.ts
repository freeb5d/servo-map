import type { FuelType } from "./fuel";
import type { BodyType } from "./vehicles";

/** A signed-in person (decision 0004). */
export interface Account {
  id: string;
  provider: "apple" | "google";
  email?: string;
  name?: string;
  /** Profile photo URL, from Google. */
  picture?: string;
  createdAt: string;
}

/** A fill-up as stored for an account; mirrors the iOS log entry. */
export interface FillUpRecord {
  id: string;
  /** ISO 8601 with timezone. */
  date: string;
  stationId: string;
  stationName: string;
  brand: string;
  fuel: FuelType;
  litres: number;
  centsPerLitre: number;
  areaAverage?: number;
}

export interface CarProfile {
  vehicleId?: string;
  name: string;
  body: BodyType;
  paint: string;
  fuel: FuelType;
  tankLitres: number;
  catalogueTankLitres?: number;
}

export interface AlertSettings {
  priceDrop: boolean;
  cycleLow: boolean;
  quietStart: number;
  quietEnd: number;
  /** Rounded to two decimals (about 1 km) before it is stored. */
  home?: { lat: number; lng: number };
}

/** `GET /api/v1/me`: everything the apps sync for an account. */
export interface MeResponse {
  account: Account;
  savedStationIds: string[];
  fillUps: FillUpRecord[];
  car?: CarProfile;
  alerts: AlertSettings;
}

/** `POST /api/v1/auth/{provider}`. */
export interface SessionResponse {
  token: string;
  account: Account;
}
