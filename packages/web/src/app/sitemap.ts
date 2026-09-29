import type { MetadataRoute } from "next";
import type { AustralianState, StateMetadata } from "@servo-map/shared";
import { getStations, getMetadata } from "@/lib/api";
import { liveStates } from "@/lib/coverage";
import { SITE_URL } from "@/lib/site";
import { uniqueSuburbs } from "@/lib/seo";

const BASE = SITE_URL;
// Per-state fetch cap (worker MAX_LIMIT). A dedicated suburb/station-index
// endpoint should replace this so we enumerate beyond the first 500 rows/state.
const PER_STATE_LIMIT = 500;

// Single sitemap served at /sitemap.xml (matches robots.txt). NOT generateSitemaps:
// Next 15 did not auto-create a /sitemap.xml index for string-id child sitemaps,
// leaving the advertised entrypoint a 404 and the children undiscoverable. With
// ~1.5k URLs we are far under the 50k single-sitemap limit, so one file is simplest
// and crawlable. Revisit (sitemap index) only if we approach the limit.
export const revalidate = 3600;

async function loadMetadata(): Promise<Record<
  AustralianState,
  StateMetadata
> | null> {
  try {
    return (await getMetadata()).data;
  } catch {
    return null;
  }
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const metadata = await loadMetadata();
  const found = metadata ? liveStates(metadata) : [];
  // Fall back to nsw so the sitemap is never empty if metadata is unreachable.
  const live = found.length ? found : (["nsw"] as AustralianState[]);

  const lastModOf = (s: AustralianState): Date => {
    const ts = metadata?.[s]?.last_updated;
    return ts ? new Date(ts) : new Date();
  };
  const latest = live
    .map((s) => lastModOf(s).getTime())
    .reduce((a, b) => Math.max(a, b), 0);
  const siteLastMod = latest ? new Date(latest) : new Date();

  const entries: MetadataRoute.Sitemap = [
    { url: BASE, lastModified: siteLastMod, changeFrequency: "hourly", priority: 1 },
    // /saved is per-device and noindex, so it is deliberately absent.
    { url: `${BASE}/trends`, lastModified: siteLastMod, changeFrequency: "daily", priority: 0.6 },
    { url: `${BASE}/about`, lastModified: siteLastMod, changeFrequency: "monthly", priority: 0.4 },
  ];

  for (const state of live) {
    const lastMod = lastModOf(state);
    entries.push({
      url: `${BASE}/fuel/${state}`,
      lastModified: lastMod,
      changeFrequency: "hourly",
      priority: 0.8,
    });

    let stations;
    try {
      const { data } = await getStations({ state, limit: PER_STATE_LIMIT });
      stations = data.filter((s) => s.state === state);
    } catch {
      continue; // skip this state's rows; keep the rest of the sitemap valid
    }

    // Suburb pages are the SEO priority — emit them first.
    for (const sub of uniqueSuburbs(stations)) {
      entries.push({
        url: `${BASE}/fuel/${state}/${sub.slug}`,
        lastModified: lastMod,
        changeFrequency: "hourly",
        priority: 0.7,
      });
    }
    for (const s of stations) {
      entries.push({
        url: `${BASE}/station/${s.id}`,
        lastModified: lastMod,
        changeFrequency: "hourly",
        priority: 0.5,
      });
    }
  }

  return entries;
}
