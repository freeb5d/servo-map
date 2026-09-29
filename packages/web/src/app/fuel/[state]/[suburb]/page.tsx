import type { Metadata } from "next";
import { notFound } from "next/navigation";
import type {
  StationWithDistance,
  AustralianState,
  PriceSnapshot,
} from "@servo-map/shared";
import { getStations, getMetadata, getTrends } from "@/lib/api";
import { latestUpdatedAt } from "@/lib/coverage";
import { SITE_URL } from "@/lib/site";
import { PriceTrendSection } from "@/components/stations/PriceTrendSection";
import { StateCycleCard } from "@/components/trends/StateCycleCard";
import { suburbStats } from "@/lib/aggregate";
import {
  slugToSuburb,
  suburbToSlug,
  toTitleCase,
  computeSuburbStats,
  avgU91,
  nearbySuburbs,
} from "@/lib/seo";
import { formatPriceCents, getFuelPrice, timeAgo } from "@/lib/utils";
import { SuburbPageClient } from "./client";

// ISR: regenerate at most every 15 minutes, generate unknown suburbs on demand.
export const revalidate = 900;
export const dynamicParams = true;

interface Props {
  params: Promise<{ state: string; suburb: string }>;
}

/** Suburbs are generated on demand via ISR — none are prebuilt at build time. */
export function generateStaticParams() {
  return [];
}

/**
 * 精确取本郊区站点。先用 suburb 参数让 Worker 服务端过滤（覆盖大州 500 cap 外的
 * 郊区），再按 slug 收紧到精确匹配（Worker 是子串匹配）。
 */
async function loadSuburbStations(
  state: string,
  suburb: string,
): Promise<StationWithDistance[]> {
  try {
    const { data } = await getStations({
      state,
      suburb: slugToSuburb(suburb),
      limit: 500,
    });
    return data.filter(
      (s) => s.state === state && suburbToSlug(s.suburb) === suburb.toLowerCase(),
    );
  } catch {
    return [];
  }
}

/**
 * 同州站点样本（用于全州 U91 均价基线 + 邻近郊区交叉链接）。
 * 受 Worker 500 cap 限制，仅为样本——用于派生统计/内链已足够，且不阻断渲染。
 */
async function loadStateStations(
  state: string,
): Promise<StationWithDistance[]> {
  try {
    const { data } = await getStations({ state, limit: 500 });
    return data.filter((s) => s.state === state);
  } catch {
    return [];
  }
}

/** Real last-updated time for this state, from the metadata endpoint. */
async function loadStateUpdatedAt(state: string): Promise<string | null> {
  try {
    const { data } = await getMetadata();
    return latestUpdatedAt(data, [state as AustralianState]);
  } catch {
    return null;
  }
}

/**
 * State-level U91 price trend. History is keyed by state, so this is the
 * state's series — the UI labels it as such. Best-effort: an empty array on
 * failure means the trend section is omitted, never blocking the page.
 */
async function loadStateTrend(state: string): Promise<PriceSnapshot[]> {
  try {
    const { data } = await getTrends(state, "U91");
    return data.series;
  } catch {
    return [];
  }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { state, suburb } = await params;
  const suburbName = toTitleCase(suburb);
  const stateUpper = state.toUpperCase();

  return {
    title: `Cheapest Fuel in ${suburbName} ${stateUpper} — ServoMap`,
    description: `Compare petrol and diesel prices at all stations in ${suburbName}, ${stateUpper}. Find the cheapest U91, U95, U98, E10 and Diesel near you.`,
    alternates: { canonical: `/fuel/${state}/${suburb}` },
    openGraph: {
      title: `Cheapest Fuel in ${suburbName} ${stateUpper}`,
      description: `Compare fuel prices at all ${suburbName} stations.`,
    },
  };
}

export default async function SuburbPage({ params }: Props) {
  const { state, suburb } = await params;
  const suburbName = toTitleCase(suburb);
  const stateUpper = state.toUpperCase();

  const [stations, stateStations, lastUpdated, trendSeries] = await Promise.all([
    loadSuburbStations(state, suburb),
    loadStateStations(state),
    loadStateUpdatedAt(state),
    loadStateTrend(state),
  ]);
  if (stations.length === 0) notFound();

  const stats = computeSuburbStats(stations);
  const stateAvgU91 = avgU91(stateStations);
  const nearby = nearbySuburbs(stateStations, suburb.toLowerCase(), state, 6);

  // Lowest U91 per suburb, so the side column can show real prices next to each neighbour.
  const minBySlug = new Map(
    suburbStats(stateStations, "U91").map((s) => [suburbToSlug(s.suburb), s.min]),
  );
  const nearbyWithPrice = nearby.map((n) => ({ ...n, minU91: minBySlug.get(n.slug) ?? null }));

  const lede = buildLede({
    suburbName,
    stateUpper,
    stats,
    stateAvgU91,
    u91Count: stations.filter((s) => getFuelPrice(s.prices, "U91")).length,
    lastUpdated,
  });

  // 模板化正文：以真实数据变量填充，清除 thin-content 阈值
  const prose = buildProse({
    suburbName,
    stateUpper,
    stats,
    stateAvgU91,
  });

  // FAQ：从真实数据生成问答，作为 FAQPage 结构化数据的来源
  const faqs = buildFaqs({ suburbName, stateUpper, stats, stateAvgU91 });

  const canonical = `${SITE_URL}/fuel/${state}/${suburb}`;

  // JSON-LD #1: ItemList of GasStations, each with current fuel offers.
  const itemListLd = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: `Fuel Stations in ${suburbName}, ${stateUpper}`,
    itemListElement: stations.map((s, i) => ({
      "@type": "ListItem",
      position: i + 1,
      item: {
        "@type": "GasStation",
        name: s.name,
        address: {
          "@type": "PostalAddress",
          streetAddress: s.address,
          addressLocality: s.suburb,
          addressRegion: s.state.toUpperCase(),
          postalCode: s.postcode,
          addressCountry: "AU",
        },
        makesOffer: s.prices.map((p) => ({
          "@type": "Offer",
          itemOffered: { "@type": "Product", name: `${p.fuel} fuel` },
          priceSpecification: {
            "@type": "UnitPriceSpecification",
            price: (p.price / 100).toFixed(3),
            priceCurrency: "AUD",
            unitCode: "LTR",
          },
        })),
      },
    })),
  };

  // JSON-LD #2: BreadcrumbList — Home › State hub › Suburb
  const breadcrumbLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: SITE_URL },
      {
        "@type": "ListItem",
        position: 2,
        name: `${stateUpper} Fuel Prices`,
        item: `${SITE_URL}/fuel/${state}`,
      },
      { "@type": "ListItem", position: 3, name: suburbName, item: canonical },
    ],
  };

  // JSON-LD #3: FAQPage — mirrors the on-page FAQ.
  const faqLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((f) => ({
      "@type": "Question",
      name: f.q,
      acceptedAnswer: { "@type": "Answer", text: f.a },
    })),
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(itemListLd) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbLd) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqLd) }}
      />
      <SuburbPageClient
        suburbName={suburbName}
        stateName={stateUpper}
        stateSlug={state.toLowerCase()}
        stations={stations}
        lastUpdated={lastUpdated}
        lede={lede}
        prose={prose}
        faqs={faqs}
        nearby={nearbyWithPrice}
        cycleCard={
          trendSeries.length > 0 ? (
            <StateCycleCard series={trendSeries} fuel="U91" stateLabel={stateUpper} />
          ) : null
        }
        priceTrend={
          trendSeries.length > 0 ? (
            <PriceTrendSection
              series={trendSeries}
              fuel="U91"
              stateLabel={stateUpper}
            />
          ) : null
        }
      />
    </>
  );
}

interface LedeInput extends ProseInput {
  u91Count: number;
  lastUpdated: string | null;
}

/** One-paragraph summary under the title, made of the page's real numbers (U91, the default fuel). */
function buildLede({ suburbName, stateUpper, stats, stateAvgU91, u91Count, lastUpdated }: LedeInput): string {
  if (!stats.cheapest) {
    return `${stats.stationCount} station${stats.stationCount !== 1 ? "s" : ""} in ${suburbName}, ${stateUpper}. None reports U91 right now; pick another fuel below.`;
  }
  let text = `${u91Count} station${u91Count !== 1 ? "s" : ""} report${u91Count === 1 ? "s" : ""} U91 in ${suburbName}. The cheapest is ${stats.cheapest.name} at ${formatPriceCents(stats.cheapest.price)}\u00A2/L`;
  if (stateAvgU91 != null) {
    const diff = stateAvgU91 - stats.cheapest.price;
    text += Math.abs(diff) < 0.05
      ? `, level with the ${stateUpper} average`
      : `, ${formatPriceCents(Math.abs(diff))}\u00A2 ${diff > 0 ? "under" : "over"} the ${stateUpper} average`;
  }
  text += ".";
  if (lastUpdated) text += ` Updated ${timeAgo(lastUpdated)} from the ${stateUpper} government feed.`;
  return text;
}

interface ProseInput {
  suburbName: string;
  stateUpper: string;
  stats: ReturnType<typeof computeSuburbStats>;
  stateAvgU91: number | null;
}

/** 生成 2-3 段模板化但由真实变量驱动的正文段落（数组，逐段渲染）。 */
function buildProse({
  suburbName,
  stateUpper,
  stats,
  stateAvgU91,
}: ProseInput): string[] {
  const paras: string[] = [];

  const countText = `${stats.stationCount} fuel station${stats.stationCount !== 1 ? "s" : ""}`;
  const brandText =
    stats.brandCount > 0
      ? ` across ${stats.brandCount} brand${stats.brandCount !== 1 ? "s" : ""} (${stats.brands.slice(0, 5).join(", ")}${stats.brands.length > 5 ? ", and more" : ""})`
      : "";
  paras.push(
    `ServoMap tracks ${countText} in ${suburbName}, ${stateUpper}${brandText}. Prices are sourced directly from the ${stateUpper} government fuel-price feed and refreshed throughout the day, so you can compare U91, E10, U95, U98 and Diesel before you fill up.`,
  );

  if (stats.avgU91 != null) {
    let avgLine = `The average U91 (regular unleaded) price in ${suburbName} is currently ${formatPriceCents(stats.avgU91)}c per litre.`;
    if (stateAvgU91 != null) {
      const diff = stats.avgU91 - stateAvgU91;
      const absDiff = Math.abs(diff);
      if (absDiff < 0.5) {
        avgLine += ` That's in line with the ${stateUpper} average of ${formatPriceCents(stateAvgU91)}c.`;
      } else if (diff < 0) {
        avgLine += ` That's ${formatPriceCents(absDiff)}c cheaper than the ${stateUpper} average of ${formatPriceCents(stateAvgU91)}c — a relatively good area to refuel.`;
      } else {
        avgLine += ` That's ${formatPriceCents(absDiff)}c dearer than the ${stateUpper} average of ${formatPriceCents(stateAvgU91)}c, so it pays to shop around.`;
      }
    }
    paras.push(avgLine);
  }

  if (stats.cheapest && stats.dearest) {
    const spread = stats.dearest.price - stats.cheapest.price;
    let priceLine = `Right now the cheapest U91 in ${suburbName} is ${formatPriceCents(stats.cheapest.price)}c at ${stats.cheapest.brand} (${stats.cheapest.name}).`;
    if (spread > 0.5 && stats.dearest.name !== stats.cheapest.name) {
      priceLine += ` The dearest is ${formatPriceCents(stats.dearest.price)}c at ${stats.dearest.brand} (${stats.dearest.name}) — a spread of ${formatPriceCents(spread)}c per litre, or about $${((spread * 50) / 100).toFixed(2)} on a 50-litre tank.`;
    }
    paras.push(priceLine);
  }

  return paras;
}

interface FaqInput {
  suburbName: string;
  stateUpper: string;
  stats: ReturnType<typeof computeSuburbStats>;
  stateAvgU91: number | null;
}

/** 从真实数据生成 3-4 条 FAQ（同时驱动页面与 FAQPage 结构化数据）。 */
function buildFaqs({
  suburbName,
  stateUpper,
  stats,
  stateAvgU91,
}: FaqInput): { q: string; a: string }[] {
  const faqs: { q: string; a: string }[] = [];

  if (stats.cheapest) {
    faqs.push({
      q: `Where is the cheapest fuel in ${suburbName}?`,
      a: `The cheapest U91 in ${suburbName} right now is ${formatPriceCents(stats.cheapest.price)}c per litre at ${stats.cheapest.brand} (${stats.cheapest.name}). ServoMap updates prices from the ${stateUpper} government feed throughout the day, so check before you head out.`,
    });
  }

  if (stats.avgU91 != null) {
    let a = `The average U91 price across ${stats.stationCount} station${stats.stationCount !== 1 ? "s" : ""} in ${suburbName} is about ${formatPriceCents(stats.avgU91)}c per litre.`;
    if (stateAvgU91 != null) {
      a += ` The ${stateUpper} state average is ${formatPriceCents(stateAvgU91)}c per litre.`;
    }
    faqs.push({
      q: `What is the average petrol price in ${suburbName}?`,
      a,
    });
  }

  faqs.push({
    q: `How many petrol stations are in ${suburbName}?`,
    a: `ServoMap currently tracks ${stats.stationCount} fuel station${stats.stationCount !== 1 ? "s" : ""} in ${suburbName}${stats.brandCount > 0 ? ` across ${stats.brandCount} brand${stats.brandCount !== 1 ? "s" : ""}` : ""}, all with live prices for U91, E10, U95, U98 and Diesel where available.`,
  });

  faqs.push({
    q: `How often are ${suburbName} fuel prices updated?`,
    a: `Prices are sourced from the official ${stateUpper} government fuel-price reporting scheme and refreshed every 15 minutes. Each station also shows when its price was last reported.`,
  });

  return faqs;
}
