import type { Station, AustralianState } from "@servo-map/shared";
import type { Env } from "../env";

export interface StateAdapter {
  /** Which states this adapter covers */
  readonly states: readonly AustralianState[];

  /**
   * Minimum minutes between fetches, for upstreams with a call quota. The ingest skips the
   * adapter while every state it covers was updated more recently than this. Omit to fetch
   * on every run.
   */
  readonly minIntervalMinutes?: number;

  /** Fetch all stations with current prices. Throws on failure. */
  fetchStations(env: Env): Promise<Station[]>;
}

// --- NSW FuelCheck API v2 raw response types ---
// /FuelPriceCheck/v2/fuel/prices 返回 stations + prices 在同一个响应中

export interface NswStation {
  brandid: string;
  stationid: string;
  brand: string;
  code: string;
  name: string;
  /** 完整地址，例如 "307-313 Ocean Beach Road, UMINA BEACH NSW 2257" */
  address: string;
  location: {
    latitude: number;
    longitude: number;
  };
  state: string;
}

export interface NswPriceEntry {
  stationcode: number;
  state: string;
  fueltype: string;
  price: number;
  /** 格式: "DD/MM/YYYY HH:mm:ss" */
  lastupdated: string;
}

export interface NswPricesResponse {
  stations: NswStation[];
  prices: NswPriceEntry[];
}

export interface NswOAuthResponse {
  access_token: string;
  expires_in: string;
  token_type: string;
}

// --- QLD Fuel Prices API raw response types ---

export interface QldSiteDetails {
  S: QldSite[];
}

export interface QldSite {
  S: number;      // SiteId
  N: string;      // SiteName
  A: string;      // Address
  B: number;      // BrandId
  Bn: string;     // BrandName
  P: string;      // Postcode
  Lt: number;     // Latitude
  Ln: number;     // Longitude
  Sb: string;     // Suburb
}

export interface QldSitePricesResponse {
  SitePrices: QldSitePrice[];
}

export interface QldSitePrice {
  SiteId: number;
  FuelId: number;
  Price: number;        // 0.1 cent units
  TransactionDateUtc: string;
}

// --- WA FuelWatch RSS raw types ---
// 公开 RSS feed，无需认证。每次请求返回单一 Product（油种），
// 每个 <item> 是一个站点的当日价格。feed 无站点 id / 邮编。
// price 已是 cents/L（如 157.3）。

export interface WaFeedItem {
  /** 商家名（trading-name），用于派生站点身份 */
  tradingName: string;
  brand: string;
  address: string;
  /** suburb（feed 中的 <location>） */
  location: string;
  lat: number;
  lng: number;
  /** cents/L，已是最终单位 */
  price: number;
}
