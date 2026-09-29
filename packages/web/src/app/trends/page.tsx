import type { Metadata } from "next";
import { Suspense } from "react";
import type { AustralianState } from "@servo-map/shared";
import { MobileTabs } from "@/components/shell/MobileTabs";
import { TopBar } from "@/components/shell/TopBar";
import { ModuleNote } from "@/components/trends/Card";
import { TrendsView, type TrendState } from "@/components/trends/TrendsView";
import { getMetadata, getTrends } from "@/lib/api";
import { liveStates } from "@/lib/coverage";

// Price history moves once a day; 15 minutes keeps the page fresh without a request per visit.
export const revalidate = 900;

export const metadata: Metadata = {
  title: "Fuel Price Trends — ServoMap",
  description:
    "Where the fuel price cycle is right now, how prices moved over 30 and 90 days, which brands and suburbs are cheapest, and which weekday to fill up.",
  alternates: { canonical: "/trends" },
  openGraph: {
    title: "Fuel Price Trends — ServoMap",
    description: "Is now a good time to fill up? Cycle position, price history and local rankings.",
  },
};

async function liveStateCodes(): Promise<AustralianState[]> {
  try {
    const { data } = await getMetadata();
    const live = liveStates(data);
    return live.length ? live : ["nsw"];
  } catch {
    return ["nsw"];
  }
}

/**
 * History for every live state is fetched here so the page stays statically cached and the
 * state switch is instant on the client. One failed state degrades to a note, not a 500.
 */
async function loadTrends(): Promise<TrendState[]> {
  const states = await liveStateCodes();
  return Promise.all(
    states.map(async (state) => {
      try {
        const { data } = await getTrends(state);
        return { state, series: data.series };
      } catch {
        return { state, series: null };
      }
    }),
  );
}

export default async function TrendsPage() {
  const states = await loadTrends();
  return (
    // useSearchParams needs a boundary; the fallback keeps the chrome while the view hydrates.
    <Suspense fallback={<TrendsFallback />}>
      <TrendsView states={states} />
    </Suspense>
  );
}

function TrendsFallback() {
  return (
    <div className="min-h-screen bg-bg">
      <TopBar active="trends" />
      <main className="mx-auto max-w-[1200px] px-3 pt-8 md:px-12">
        <ModuleNote busy>Loading price trends.</ModuleNote>
      </main>
      <MobileTabs active="trends" />
    </div>
  );
}
