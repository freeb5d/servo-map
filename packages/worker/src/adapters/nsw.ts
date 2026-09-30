import type { Station, FuelPrice, AustralianState } from "@servo-map/shared";
import type { Env } from "../env";
import type {
  StateAdapter,
  NswPricesResponse,
  NswOAuthResponse,
  NswStation,
} from "./types";
import { mapNswFuelType } from "../utils/fuel-map";
import { titleCasePlace } from "../utils/place-names";

const OAUTH_URL =
  "https://api.onegov.nsw.gov.au/oauth/client_credential/accesstoken?grant_type=client_credentials";
const BASE_URL = "https://api.onegov.nsw.gov.au/FuelPriceCheck/v2";

/** 获取 OAuth Bearer token（有效期 ~12 小时） */
async function requestAccessToken(authHeader: string): Promise<string> {
  const res = await fetch(OAUTH_URL, {
    method: "GET",
    headers: { Authorization: authHeader },
  });
  if (!res.ok) {
    throw new Error(`NSW OAuth error: ${res.status} ${res.statusText}`);
  }
  const data = (await res.json()) as NswOAuthResponse;
  return data.access_token;
}

// NSW 与 TAS adapter 在同一次 ingest 中并行运行：共用一次 token 请求，省下 API 配额。
// ingest 进程只活几分钟，远短于 token 的 12 小时有效期，因此不做过期处理。
let cachedToken: { authHeader: string; token: Promise<string> } | null = null;

function getAccessToken(authHeader: string): Promise<string> {
  if (cachedToken?.authHeader === authHeader) return cachedToken.token;
  const token = requestAccessToken(authHeader);
  cachedToken = { authHeader, token };
  // 失败的 token 不缓存，下一次调用重新请求
  token.catch(() => {
    if (cachedToken?.token === token) cachedToken = null;
  });
  return token;
}

/** 带完整 auth headers 的请求 */
async function fetchWithAuth<T>(
  url: string,
  token: string,
  apiKey: string,
): Promise<T> {
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: apiKey,
      transactionid: crypto.randomUUID(),
      requesttimestamp: new Date()
        .toLocaleString("en-AU", {
          timeZone: "UTC",
          day: "2-digit",
          month: "2-digit",
          year: "numeric",
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
          hour12: false,
        })
        .replace(",", ""),
      "Content-Type": "application/json",
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`NSW API error: ${res.status} ${res.statusText} — ${body}`);
  }
  return res.json() as Promise<T>;
}

/** 从 NSW 地址字符串中解析 suburb 和 postcode */
function parseAddress(raw: string): { suburb: string; postcode: string } {
  // 典型格式: "307-313 Ocean Beach Road, UMINA BEACH NSW 2257"
  const match = raw.match(/,\s*(.+?)\s+(?:NSW|TAS|ACT)\s+(\d{4})$/i);
  if (match) {
    return {
      suburb: match[1].trim(),
      postcode: match[2],
    };
  }
  // fallback: 尝试只取最后的 postcode
  const pcMatch = raw.match(/(\d{4})$/);
  return {
    suburb: "",
    postcode: pcMatch?.[1] ?? "",
  };
}

/** 将 NSW lastupdated 字符串转为 ISO 8601 */
function parseNswDate(raw: string): string {
  // "28/03/2026 01:20:38" → ISO
  const match = raw.match(/(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/);
  if (!match) return new Date().toISOString();
  const [, dd, mm, yyyy, hh, min, ss] = match;
  return new Date(`${yyyy}-${mm}-${dd}T${hh}:${min}:${ss}Z`).toISOString();
}

/**
 * 站点所属州。FuelCheck 把 ACT 站点的 state 标成 "NSW"，地址结尾（"… ACT 2612"）才可靠，
 * 所以优先用地址后缀，没有后缀时才退回 state 字段。
 */
function stationState(ref: NswStation): AustralianState | null {
  const suffix = ref.address.match(/\b(NSW|ACT|TAS)\s+\d{4}\s*$/i)?.[1];
  return mapState(suffix ?? ref.state);
}

/** 将 NSW state 字符串映射到统一 AustralianState */
function mapState(raw: string): AustralianState | null {
  const mapping: Record<string, AustralianState> = {
    nsw: "nsw",
    "new south wales": "nsw",
    tas: "tas",
    tasmania: "tas",
    act: "act",
    "australian capital territory": "act",
  };
  return mapping[raw.toLowerCase().trim()] ?? null;
}

/**
 * 抓取一次 FuelCheck v2 全量价格并转换为 Station[]。
 *
 * 不带参数只返回 NSW 源（含 ACT 站点）；TAS 需要单独请求 `?states=TAS`。
 * 只保留 `states` 内的站点，避免两个 adapter 产出同一站点。
 */
export async function fetchFuelCheckStations(
  env: Env,
  states: readonly AustralianState[],
  query = "",
): Promise<Station[]> {
  // Step 1: 获取 OAuth token（同一次 ingest 内共用）
  const token = await getAccessToken(env.NSW_API_AUTH);

  // Step 2: 获取所有站点 + 价格（单次请求）
  const data = await fetchWithAuth<NswPricesResponse>(
    `${BASE_URL}/fuel/prices${query}`,
    token,
    env.NSW_API_KEY,
  );

  // 按 station code 索引站点数据
  const stationMap = new Map<string, NswStation>();
  for (const s of data.stations) {
    stationMap.set(s.code, s);
  }

  // 按 station code 聚合油价
  const pricesByStation = new Map<string, FuelPrice[]>();
  for (const p of data.prices) {
    const fuelType = mapNswFuelType(p.fueltype);
    if (!fuelType) continue;

    const code = String(p.stationcode);
    const prices = pricesByStation.get(code) ?? [];
    prices.push({
      fuel: fuelType,
      price: p.price,
      updated_at: parseNswDate(p.lastupdated),
    });
    pricesByStation.set(code, prices);
  }

  // 合并为 Station[]
  const stations: Station[] = [];
  for (const [code, prices] of pricesByStation) {
    const ref = stationMap.get(code);
    if (!ref) continue;
    if (!ref.location?.latitude || !ref.location?.longitude) continue;

    const state = stationState(ref);
    if (!state || !states.includes(state)) continue;

    const { suburb, postcode } = parseAddress(ref.address);

    stations.push({
      id: `${state}-${code}`,
      name: titleCasePlace(ref.name),
      brand: ref.brand,
      address: titleCasePlace(ref.address),
      suburb: titleCasePlace(suburb),
      state,
      postcode,
      lat: ref.location.latitude,
      lng: ref.location.longitude,
      prices,
    });
  }

  return stations;
}

/** NSW FuelCheck 源：NSW 与 ACT（ACT 站点在 NSW 源里） */
const NSW_FEED_STATES = ["nsw", "act"] as const;

export const nswAdapter: StateAdapter = {
  states: NSW_FEED_STATES,

  fetchStations(env: Env): Promise<Station[]> {
    return fetchFuelCheckStations(env, NSW_FEED_STATES);
  },
};
