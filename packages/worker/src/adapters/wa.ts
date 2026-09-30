import type { Station, FuelPrice } from "@servo-map/shared";
import type { Env } from "../env";
import type { StateAdapter, WaFeedItem } from "./types";
import { mapWaFuelType, WA_FUEL_PRODUCTS } from "../utils/fuel-map";
import { titleCasePlace } from "../utils/place-names";

// WA FuelWatch 是公开 RSS feed，无需认证 / API key。
const BASE_URL = "https://www.fuelwatch.wa.gov.au/fuelwatch/fuelWatchRSS";

/** 抓取单一 Product 的 RSS（公开 feed，无 auth），返回原始 XML 文本 */
async function fetchRss(product: number): Promise<string> {
  const res = await fetch(`${BASE_URL}?Product=${product}`);
  if (!res.ok) {
    throw new Error(`WA API error: ${res.status} ${res.statusText}`);
  }
  return res.text();
}

/** 解码 RSS 文本节点里的基础 XML 实体 */
function decodeEntities(raw: string): string {
  return raw
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

/** 取 <item> 内某叶子标签的文本（FuelWatch 的 item 是扁平结构，无嵌套） */
function tag(itemXml: string, name: string): string {
  const m = itemXml.match(
    new RegExp(`<${name}>([\\s\\S]*?)</${name}>`, "i"),
  );
  return m ? decodeEntities(m[1].trim()) : "";
}

/**
 * 解析 FuelWatch RSS 为 WaFeedItem[]。
 *
 * feed 结构扁平且稳定（每个 <item> 仅含叶子标签），用聚焦的正则解析即可，
 * 避免为 worker 引入 XML 依赖。坐标 / 价格无效的条目在此丢弃。
 */
export function parseWaFeed(xml: string): WaFeedItem[] {
  const items: WaFeedItem[] = [];
  const itemRe = /<item>([\s\S]*?)<\/item>/gi;
  let match: RegExpExecArray | null;
  while ((match = itemRe.exec(xml)) !== null) {
    const itemXml = match[1];
    const lat = parseFloat(tag(itemXml, "latitude"));
    const lng = parseFloat(tag(itemXml, "longitude"));
    const price = parseFloat(tag(itemXml, "price"));
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    if (!Number.isFinite(price)) continue;

    items.push({
      tradingName: tag(itemXml, "trading-name"),
      brand: tag(itemXml, "brand"),
      address: tag(itemXml, "address"),
      location: tag(itemXml, "location"),
      lat,
      lng,
      price,
    });
  }
  return items;
}

/**
 * FNV-1a 32-bit 哈希。feed 无站点 id，用 brand|name|address|suburb 派生稳定 id，
 * 保证对相同上游数据重复运行得到相同 "wa-<hash>"。
 */
function siteHash(item: WaFeedItem): string {
  const seed = `${item.brand}|${item.tradingName}|${item.address}|${item.location}`;
  let h = 0x811c9dc5;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16);
}

export const waAdapter: StateAdapter = {
  states: ["wa"] as const,

  // WA FuelWatch 是公开 feed，无需 secrets —— env 不使用（前缀 _ 满足 lint）
  async fetchStations(_env: Env): Promise<Station[]> {
    // 每个 Product 一次 RSS 请求；并行抓取，单个失败不应让整个州失败
    const results = await Promise.allSettled(
      WA_FUEL_PRODUCTS.map((product) =>
        fetchRss(product).then((xml) => ({ product, items: parseWaFeed(xml) })),
      ),
    );

    // 至少一个 Product 成功才算有数据；全部失败则抛出，触发 cron 重试
    const fulfilled = results.filter(
      (r): r is PromiseFulfilledResult<{ product: number; items: WaFeedItem[] }> =>
        r.status === "fulfilled",
    );
    if (fulfilled.length === 0) {
      throw new Error("WA API error: all FuelWatch product feeds failed");
    }

    // FuelWatch 每天发布"次日"价格，无逐条时间戳 —— 用当前时间作为 updated_at
    const updatedAt = new Date().toISOString();

    // 按派生 id 聚合站点 + 各 Product 的价格
    const byId = new Map<string, Station>();
    for (const { product, items } of fulfilled.map((r) => r.value)) {
      const fuel = mapWaFuelType(product);
      if (!fuel) continue;

      for (const item of items) {
        const id = `wa-${siteHash(item)}`;
        const fuelPrice: FuelPrice = {
          fuel,
          price: item.price, // 已是 cents/L
          updated_at: updatedAt,
        };

        const existing = byId.get(id);
        if (existing) {
          // 同站点不同 Product；避免同一 fuel 重复
          if (!existing.prices.some((p) => p.fuel === fuel)) {
            existing.prices.push(fuelPrice);
          }
          continue;
        }

        // Recase only the stored copy: siteHash reads the raw feed text, so ids stay stable.
        byId.set(id, {
          id,
          name: titleCasePlace(item.tradingName),
          brand: item.brand,
          address: titleCasePlace(item.address),
          suburb: titleCasePlace(item.location),
          state: "wa",
          postcode: "", // FuelWatch feed 不含邮编
          lat: item.lat,
          lng: item.lng,
          prices: [fuelPrice],
        });
      }
    }

    return [...byId.values()];
  },
};
