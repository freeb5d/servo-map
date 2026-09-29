import type { FuelPrice } from "@servo-map/shared";
import { color } from "@servo-map/design-tokens";
import type { Theme } from "@/lib/theme";

// --- 价格颜色基于百分位动态计算 ---

export interface PriceRange {
  /** 低于此值为 cheap（绿色），P33 */
  cheapBelow: number;
  /** 低于此值为 mid（黄色），P66 */
  midBelow: number;
}

/**
 * 从一组价格中计算百分位阈值
 * 底部 33% = cheap, 中间 33% = mid, 顶部 33% = expensive
 */
export function computePriceRange(prices: number[]): PriceRange {
  if (prices.length === 0) return { cheapBelow: 0, midBelow: 0 };
  const sorted = [...prices].sort((a, b) => a - b);
  const p33 = sorted[Math.floor(sorted.length * 0.33)] ?? sorted[0];
  const p66 = sorted[Math.floor(sorted.length * 0.66)] ?? sorted[sorted.length - 1];
  return { cheapBelow: p33, midBelow: p66 };
}

/** 价格档位：cheap / fair / pricey（相对附近站点）。颜色之外的非颜色信号。 */
export type PriceTier = "cheap" | "fair" | "pricey";

/** 把价格归入档位；无 range（单站点/数据不足）时归为 fair 以免误判便宜。 */
export function priceTier(price: number, range?: PriceRange): PriceTier {
  if (!range) return "fair";
  if (price <= range.cheapBelow) return "cheap";
  if (price <= range.midBelow) return "fair";
  return "pricey";
}

/** 档位的人类可读标签，作为颜色之外的文本信号（WCAG 1.4.1）。 */
export const TIER_LABELS: Record<PriceTier, string> = {
  cheap: "Cheap",
  fair: "Fair",
  pricey: "Pricey",
};

/** 档位 → 文字色 class；仅用于档位标记（■）与标签，价格数字本身保持 ink。 */
export const TIER_TEXT_CLASS: Record<PriceTier, string> = {
  cheap: "text-price-cheap",
  fair: "text-price-mid",
  pricey: "text-price-expensive",
};

export function priceColorClass(price: number, range?: PriceRange): string {
  return TIER_TEXT_CLASS[priceTier(price, range)];
}

// Tier colours come from the token package so Mapbox paint (which cannot read CSS
// variables) and the DOM never drift apart.
const TIER_COLOR = {
  cheap: color.priceCheap,
  fair: color.priceMid,
  pricey: color.priceExpensive,
} as const;

/**
 * 按主题返回档位对应的十六进制颜色。
 * 仅用于 Mapbox 样式表达式这类无法消费 CSS 变量的地方；
 * DOM 文本应优先用 priceColorClass（自动跟随 data-theme 切换）。
 */
export function priceColorHex(
  price: number,
  range?: PriceRange,
  theme: Theme = "light",
): string {
  if (!range) return color.ink3[theme];
  return TIER_COLOR[priceTier(price, range)][theme];
}

/** 档位 → 主题色（供 MapView symbol paint 的 match 表达式直接取色）。 */
export function tierHex(tier: PriceTier, theme: Theme): string {
  return TIER_COLOR[tier][theme];
}

/**
 * 格式化价格显示：分 → 元.分
 */
export function formatPrice(cents: number): string {
  return (cents / 100).toFixed(1);
}

/**
 * 格式化价格（保留原始分数显示）
 */
export function formatPriceCents(cents: number): string {
  return cents.toFixed(1);
}

/**
 * 获取某种燃油的价格
 */
export function getFuelPrice(
  prices: FuelPrice[],
  fuelType: string,
): FuelPrice | undefined {
  return prices.find((p) => p.fuel === fuelType);
}

/**
 * 两个经纬度之间的大圆距离（km）。
 * 用于地图视野变化时判断是否值得重新请求，减少冗余的 Worker/Mapbox 调用。
 */
export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371; // 地球半径 km
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/**
 * 格式化距离显示
 */
export function formatDistance(km: number): string {
  if (km < 1) return `${Math.round(km * 1000)}m`;
  return `${km.toFixed(1)}km`;
}

/**
 * 格式化相对时间
 */
export function timeAgo(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diffMin = Math.floor((now - then) / 60000);

  if (diffMin < 1) return "just now";
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  const diffDay = Math.floor(diffHr / 24);
  return `${diffDay}d ago`;
}

/** 数据新鲜度等级 */
export type FreshnessLevel = "live" | "recent" | "stale";

/**
 * 根据 last_updated ISO 时间把数据分级：
 * - live   < 1h（绿）
 * - recent < 12h（黄）
 * - stale  >= 12h（红）
 * 6h 为 recent 内部的次级提示边界（amber 加深），见 FreshnessBadge。
 */
export function freshnessLevel(dateStr: string): FreshnessLevel {
  const diffHr = (Date.now() - new Date(dateStr).getTime()) / 3_600_000;
  if (diffHr < 1) return "live";
  if (diffHr < 12) return "recent";
  return "stale";
}

/** 数据是否已过期（> ~12h），用于展示横幅告警 */
export function isStale(dateStr: string): boolean {
  return freshnessLevel(dateStr) === "stale";
}

/**
 * classnames 简易合并工具
 */
export function cn(...classes: (string | false | null | undefined)[]): string {
  return classes.filter(Boolean).join(" ");
}
