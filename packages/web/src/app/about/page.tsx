import type { Metadata } from "next";
import Link from "next/link";
import type { AustralianState } from "@servo-map/shared";
import { getMetadata } from "@/lib/api";
import { liveStates, STATE_LABELS } from "@/lib/coverage";
import { SITE_URL } from "@/lib/site";
import { Crumbs, DocPage, DocTitle } from "@/components/doc/DocPage";
import { TopBar } from "@/components/shell/TopBar";
import { Icon } from "@/components/ui/Icon";

// 内容随覆盖范围变化，但变动缓慢 —— 1 小时 ISR 足够。
export const revalidate = 3600;

export const metadata: Metadata = {
  title: "About ServoMap — How We Source Fuel Prices",
  description:
    "ServoMap aggregates official state government fuel-price feeds into one Australia-wide map. Learn our methodology and per-state data provenance.",
  alternates: { canonical: "/about" },
  openGraph: {
    title: "About ServoMap — How We Source Fuel Prices",
    description:
      "How ServoMap sources, normalises and refreshes Australian fuel prices.",
  },
};

/**
 * 各州数据出处（provenance）。仅展示当前 live 的州，但出处文案为所有州预置，
 * 便于上线新州时无需改动此页。来源名称需与官方计划一致以建立可信度。
 */
const PROVENANCE: Record<
  AustralianState,
  { source: string; url: string; note: string }
> = {
  nsw: {
    source: "NSW Government FuelCheck",
    url: "https://www.fuelcheck.nsw.gov.au/",
    note: "Mandatory real-time price reporting under the NSW Fuel Price Reporting scheme.",
  },
  qld: {
    source: "Queensland Government Fuel Price Reporting",
    url: "https://www.qld.gov.au/transport/projects/fuel-price-reporting",
    note: "Real-time prices published under Queensland's mandatory fuel-price reporting scheme.",
  },
  vic: {
    source: "Victorian Government fuel-price data",
    url: "https://www.vic.gov.au/",
    note: "Pending integration.",
  },
  wa: {
    source: "WA FuelWatch",
    url: "https://www.fuelwatch.wa.gov.au/",
    note: "Pending integration. FuelWatch publishes next-day prices.",
  },
  sa: {
    source: "South Australian fuel-price data",
    url: "https://www.sa.gov.au/",
    note: "Pending integration.",
  },
  tas: {
    source: "Tasmanian fuel-price data",
    url: "https://www.tas.gov.au/",
    note: "Pending integration.",
  },
  act: {
    source: "ACT fuel-price data",
    url: "https://www.act.gov.au/",
    note: "Pending integration.",
  },
  nt: {
    source: "NT MyFuel",
    url: "https://fuel.nt.gov.au/",
    note: "Pending integration.",
  },
};

async function loadLiveStates(): Promise<AustralianState[]> {
  try {
    const { data } = await getMetadata();
    const states = liveStates(data);
    return states.length ? states : ["nsw"];
  } catch {
    return ["nsw"];
  }
}

export default async function AboutPage() {
  const live = await loadLiveStates();

  const breadcrumbLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: SITE_URL },
      {
        "@type": "ListItem",
        position: 2,
        name: "About",
        item: `${SITE_URL}/about`,
      },
    ],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbLd) }}
      />
      <DocPage topBar={<TopBar active={null} />}>
        <Crumbs items={[{ label: "About" }]} />
        <div className="grid gap-2">
          <p className="caption">Methodology</p>
          <DocTitle>How ServoMap works</DocTitle>
        </div>

          <section className="grid gap-4 text-ink-2">
            <p>
              ServoMap is a free Australia-wide fuel-price map. We aggregate each
              state&rsquo;s official fuel-price feed into one normalised dataset,
              so you can compare U91, E10, U95, U98 and Diesel across every
              covered station in one place.
            </p>
            <p>
              Prices are pulled directly from government sources every 15 minutes
              and stored at the edge for fast delivery. Each station and suburb
              page shows when its price was last reported, so you always know how
              fresh the data is. We never estimate or interpolate prices — if a
              station hasn&rsquo;t reported, we don&rsquo;t show a price for it.
            </p>
          </section>

          <section>
            <h2 className="font-display text-heading font-semibold text-ink mb-4">
              Where the data comes from
            </h2>
            <p className="text-body text-ink-2 mb-6">
              ServoMap is currently live in{" "}
              {live.map((s, i) => (
                <span key={s}>
                  <Link href={`/fuel/${s}`} className="link">
                    {STATE_LABELS[s]}
                  </Link>
                  {i < live.length - 1 ? ", " : ""}
                </span>
              ))}
              . Each state&rsquo;s prices are sourced from its official
              government reporting scheme:
            </p>
            <dl className="space-y-4">
              {live.map((s) => {
                const p = PROVENANCE[s];
                return (
                  <div
                    key={s}
                    className="rounded-3 border border-line-subtle bg-surface px-5 py-4"
                  >
                    <dt className="flex items-center gap-2">
                      <span className="caption">
                        {STATE_LABELS[s]}
                      </span>
                      <span className="text-body font-medium text-ink">
                        {p.source}
                      </span>
                    </dt>
                    <dd className="text-body text-ink-2 mt-2">
                      {p.note}{" "}
                      <a
                        href={p.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="link"
                      >
                        Official source
                      </a>
                    </dd>
                  </div>
                );
              })}
            </dl>
          </section>

          <section className="grid gap-4 text-ink-2">
            <h2 className="font-display text-heading font-semibold text-ink">
              Accuracy &amp; freshness
            </h2>
            <p>
              Fuel prices change frequently and reporting can lag at individual
              stations. Always confirm the price at the bowser before you fill
              up. ServoMap is an independent project and is not affiliated with
              any government agency or fuel retailer.
            </p>
          </section>

          <div>
            <Link href="/" className="btn btn-primary">
              Open the live map
              <Icon name="arrow-right" />
            </Link>
          </div>
      </DocPage>
    </>
  );
}
