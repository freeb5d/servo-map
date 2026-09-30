import type { Station, FuelPrice } from "@servo-map/shared";
import type { Env } from "../env";
import type {
  StateAdapter,
  QldSiteDetails,
  QldSitePricesResponse,
} from "./types";
import { mapQldFuelType } from "../utils/fuel-map";
import { titleCasePlace } from "../utils/place-names";

const BASE_URL = "https://fppdirectapi-prod.fuelpricesqld.com.au";

async function fetchWithAuth<T>(url: string, token: string): Promise<T> {
  const res = await fetch(url, {
    headers: {
      Authorization: `FPDAPI SubscriberToken=${token}`,
      "Content-Type": "application/json",
    },
  });
  if (!res.ok) {
    throw new Error(`QLD API error: ${res.status} ${res.statusText}`);
  }
  return res.json() as Promise<T>;
}

export const qldAdapter: StateAdapter = {
  states: ["qld"] as const,

  async fetchStations(env: Env): Promise<Station[]> {
    const [sites, pricesRes] = await Promise.all([
      fetchWithAuth<QldSiteDetails>(
        `${BASE_URL}/Subscriber/GetFullSiteDetails?countryId=21&geoRegionLevel=3&geoRegionId=1`,
        env.QLD_API_TOKEN,
      ),
      fetchWithAuth<QldSitePricesResponse>(
        `${BASE_URL}/Price/GetSitesPrices?countryId=21&geoRegionLevel=3&geoRegionId=1`,
        env.QLD_API_TOKEN,
      ),
    ]);

    // 按 SiteId 聚合油价
    const pricesBySite = new Map<number, FuelPrice[]>();
    for (const p of pricesRes.SitePrices) {
      const fuelType = mapQldFuelType(p.FuelId);
      if (!fuelType) continue;

      const prices = pricesBySite.get(p.SiteId) ?? [];
      prices.push({
        fuel: fuelType,
        price: p.Price / 10, // 0.1 分 → 分/升
        updated_at: p.TransactionDateUtc,
      });
      pricesBySite.set(p.SiteId, prices);
    }

    // 合并为 Station[]
    const stations: Station[] = [];
    for (const site of sites.S) {
      if (!site.Lt || !site.Ln) continue;

      const prices = pricesBySite.get(site.S) ?? [];
      stations.push({
        id: `qld-${site.S}`,
        name: titleCasePlace(site.N),
        brand: site.Bn,
        address: titleCasePlace(site.A),
        suburb: titleCasePlace(site.Sb),
        state: "qld",
        postcode: site.P,
        lat: site.Lt,
        lng: site.Ln,
        prices,
      });
    }

    return stations;
  },
};
