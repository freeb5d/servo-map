import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import { AUSTRALIAN_STATES, type AustralianState } from "@servo-map/shared";
import type { PriceSnapshot } from "@servo-map/shared";
import { getStations, getMetadata, getTrends } from "@/lib/api";
import { latestUpdatedAt, liveStates, STATE_LABELS } from "@/lib/coverage";
import { SITE_URL } from "@/lib/site";
import { uniqueSuburbs } from "@/lib/seo";
import { Crumbs, DocFooter, DocPage, DocTitle } from "@/components/doc/DocPage";
import { TopBar } from "@/components/shell/TopBar";
import { FreshnessBadge } from "@/components/stations/FreshnessBadge";
import { PriceTrendSection } from "@/components/stations/PriceTrendSection";
import { StateCycleCard } from "@/components/trends/StateCycleCard";

// ISR: regenerate at most every 15 minutes, generate unknown states on demand.
export const revalidate = 900;
export const dynamicParams = true;

interface Props {
  params: Promise<{ state: string }>;
}

/** State hubs are generated on demand via ISR — none are prebuilt at build time. */
export function generateStaticParams() {
  return [];
}

/** Whether a given path segment is a real state code AND currently has live data. */
async function loadIfLive(state: string): Promise<{
  live: boolean;
  lastUpdated: string | null;
}> {
  if (!AUSTRALIAN_STATES.includes(state as AustralianState)) {
    return { live: false, lastUpdated: null };
  }
  try {
    const { data } = await getMetadata();
    const live = liveStates(data).includes(state as AustralianState);
    return { live, lastUpdated: latestUpdatedAt(data, [state as AustralianState]) };
  } catch {
    return { live: false, lastUpdated: null };
  }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { state } = await params;
  const stateUpper = state.toUpperCase();

  return {
    title: `${stateUpper} Fuel Prices by Suburb — ServoMap`,
    description: `Browse live petrol and diesel prices across every ${stateUpper} suburb. Find the cheapest U91, E10, U95, U98 and Diesel near you.`,
    alternates: { canonical: `/fuel/${state.toLowerCase()}` },
    openGraph: {
      title: `${stateUpper} Fuel Prices by Suburb`,
      description: `Live fuel prices across ${stateUpper} suburbs on ServoMap.`,
    },
  };
}

export default async function StateHubPage({ params }: Props) {
  const { state } = await params;
  const stateLower = state.toLowerCase();
  const stateUpper = state.toUpperCase();

  // 仅对真实有数据的州渲染 hub —— 避免对空州过度声明覆盖（与 §honest coverage 一致）
  const { live, lastUpdated } = await loadIfLive(stateLower);
  if (!live) notFound();

  let suburbs: ReturnType<typeof uniqueSuburbs> = [];
  try {
    const { data } = await getStations({ state: stateLower, limit: 500 });
    suburbs = uniqueSuburbs(data.filter((s) => s.state === stateLower));
  } catch {
    suburbs = [];
  }
  if (suburbs.length === 0) notFound();

  const stationTotal = suburbs.reduce((sum, s) => sum + s.stationCount, 0);
  const stateLabel = STATE_LABELS[stateLower as AustralianState] ?? stateUpper;

  // State-level price trend (default fuel U91). Best-effort: omit the section
  // entirely on fetch failure or empty series so the hub never half-renders it.
  let trendSeries: PriceSnapshot[] = [];
  try {
    const { data } = await getTrends(stateLower, "U91");
    trendSeries = data.series;
  } catch {
    trendSeries = [];
  }

  // BreadcrumbList JSON-LD: Home › State hub
  const breadcrumbLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: SITE_URL },
      {
        "@type": "ListItem",
        position: 2,
        name: `${stateLabel} Fuel Prices`,
        item: `${SITE_URL}/fuel/${stateLower}`,
      },
    ],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbLd) }}
      />
      <DocPage
        topBar={<TopBar active={null} />}
        aside={
          <>
            {trendSeries.length > 0 && (
              <StateCycleCard series={trendSeries} fuel="U91" stateLabel={stateUpper} />
            )}
            <Link href="/" className="btn btn-primary">
              Open the live map
            </Link>
          </>
        }
      >
        <Crumbs items={[{ label: stateLabel }]} />
        <DocTitle>{stateLabel} fuel prices by suburb</DocTitle>
        <div className="grid max-w-[36em] gap-3">
          <p className="text-body text-ink-2">
            {suburbs.length} suburb{suburbs.length !== 1 ? "s" : ""} and {stationTotal} station
            {stationTotal !== 1 ? "s" : ""} report prices across {stateLabel}, sourced from the official{" "}
            {stateUpper} government fuel-price feed and refreshed every 15 minutes. Pick a suburb to compare
            U91, E10, U95, U98 and Diesel, or open the{" "}
            <Link href="/" className="link">
              live map
            </Link>
            .
          </p>
          {lastUpdated && (
            <div>
              <FreshnessBadge lastUpdated={lastUpdated} />
            </div>
          )}
        </div>

        {/* 郊区列表 — 链接到每个 /fuel/<state>/<suburb> */}
        <section className="grid gap-3">
          <h2 className="caption">All suburbs</h2>
          <ul className="grid grid-cols-2 gap-2 sm:grid-cols-3 animate-rise-in">
            {suburbs.map((s) => (
              <li key={s.slug}>
                <Link
                  href={`/fuel/${stateLower}/${s.slug}`}
                  className="btn btn-secondary w-full justify-between"
                >
                  <span className="truncate font-medium">{s.name}</span>
                  <span className="shrink-0 text-small text-ink-3">{s.stationCount}</span>
                </Link>
              </li>
            ))}
          </ul>
        </section>

        {/* State-level price trend — labelled honestly as the whole state */}
        {trendSeries.length > 0 && (
          <PriceTrendSection series={trendSeries} fuel="U91" stateLabel={stateUpper} />
        )}

        <DocFooter lastUpdated={lastUpdated} state={stateLower as AustralianState} />
      </DocPage>
    </>
  );
}
