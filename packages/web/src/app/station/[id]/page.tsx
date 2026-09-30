import type { Metadata } from "next";
import { notFound, permanentRedirect } from "next/navigation";
import type { Station, AustralianState } from "@servo-map/shared";
import { getStation, getMetadata } from "@/lib/api";
import { latestUpdatedAt } from "@/lib/coverage";
import { suburbToSlug } from "@/lib/seo";
import { SITE_URL } from "@/lib/site";
import { StationPageClient } from "./client";

// ISR: regenerate at most every 15 minutes, generate unknown stations on demand.
export const revalidate = 900;
export const dynamicParams = true;

interface Props {
  params: Promise<{ id: string }>;
}

/** Stations are generated on demand via ISR — none are prebuilt at build time. */
export function generateStaticParams() {
  return [];
}

/** Fetch a single station. Returns null on 404 / API failure. */
async function loadStation(id: string): Promise<Station | null> {
  try {
    const { data } = await getStation(id);
    return data;
  } catch {
    return null;
  }
}

/** Real last-updated time for this station's state, from the metadata endpoint. */
async function loadStateUpdatedAt(state: AustralianState): Promise<string | null> {
  try {
    const { data } = await getMetadata();
    return latestUpdatedAt(data, [state]);
  } catch {
    return null;
  }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const station = await loadStation(id);
  if (!station) return { title: "Station Not Found — ServoMap" };

  return {
    title: `${station.name} Fuel Prices — ServoMap`,
    description: `Live fuel prices at ${station.name}, ${station.suburb} ${station.state.toUpperCase()}. Compare petrol and diesel prices.`,
    alternates: { canonical: `/station/${station.id}` },
    openGraph: {
      title: `${station.name} — ServoMap`,
      description: `Live fuel prices at ${station.name}, ${station.suburb}.`,
    },
  };
}

export default async function StationPage({ params }: Props) {
  const { id } = await params;
  const station = await loadStation(id);
  if (!station) notFound();
  // A retired id (ACT stations were "nsw-<code>") answers with the current one; move the URL too.
  if (station.id !== id) permanentRedirect(`/station/${station.id}`);

  const lastUpdated = await loadStateUpdatedAt(station.state);

  // 站点所属郊区页的链接（用于面包屑 + 客户端 backlink）
  const stateLower = station.state.toLowerCase();
  const suburbSlug = suburbToSlug(station.suburb);
  const suburbHref = `/fuel/${stateLower}/${suburbSlug}`;

  // JSON-LD: GasStation with geo + current fuel offers (price per litre, AUD).
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "GasStation",
    name: station.name,
    address: {
      "@type": "PostalAddress",
      streetAddress: station.address,
      addressLocality: station.suburb,
      addressRegion: station.state.toUpperCase(),
      postalCode: station.postcode,
      addressCountry: "AU",
    },
    geo: {
      "@type": "GeoCoordinates",
      latitude: station.lat,
      longitude: station.lng,
    },
    makesOffer: station.prices.map((p) => ({
      "@type": "Offer",
      itemOffered: { "@type": "Product", name: `${p.fuel} fuel` },
      priceSpecification: {
        "@type": "UnitPriceSpecification",
        price: (p.price / 100).toFixed(3),
        priceCurrency: "AUD",
        unitCode: "LTR",
      },
    })),
  };

  // BreadcrumbList JSON-LD: Home › State hub › Suburb › Station
  const breadcrumbLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: SITE_URL },
      {
        "@type": "ListItem",
        position: 2,
        name: `${station.state.toUpperCase()} Fuel Prices`,
        item: `${SITE_URL}/fuel/${stateLower}`,
      },
      {
        "@type": "ListItem",
        position: 3,
        name: station.suburb,
        item: `${SITE_URL}${suburbHref}`,
      },
      {
        "@type": "ListItem",
        position: 4,
        name: station.name,
        item: `${SITE_URL}/station/${id}`,
      },
    ],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbLd) }}
      />
      <StationPageClient
        station={station}
        lastUpdated={lastUpdated}
        suburbHref={suburbHref}
      />
    </>
  );
}
