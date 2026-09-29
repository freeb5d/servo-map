import { Suspense } from "react";
import Link from "next/link";
import type { AustralianState } from "@servo-map/shared";
import { getMetadata } from "@/lib/api";
import { liveStates, formatLiveStates, STATE_LABELS } from "@/lib/coverage";
import HomeMap from "./client";

// 首页是服务端外壳：渲染可索引的 SSR 介绍 + 内链，再挂载客户端地图组件。
// ISR：live 州集合变动缓慢，15 分钟足够。
export const revalidate = 900;

/** 服务端解析 live 州，用于渲染真实的州 hub 内链（无数据时回退 nsw）。 */
async function loadLiveStates(): Promise<AustralianState[]> {
  try {
    const { data } = await getMetadata();
    const states = liveStates(data);
    return states.length ? states : ["nsw"];
  } catch {
    return ["nsw"];
  }
}

export default async function Home() {
  const live = await loadLiveStates();
  const liveText = formatLiveStates(live);

  return (
    <>
      {/* Interactive map app fills the first viewport. useSearchParams needs a Suspense boundary. */}
      <Suspense fallback={<div className="h-dvh bg-bg" aria-hidden="true" />}>
        <HomeMap />
      </Suspense>

      {/*
        Server-rendered, indexable content: the client map renders no real h1 or internal links,
        so they live here. It sits after the app viewport in normal flow, fully readable by
        crawlers, and shows as the page footer when scrolled to.
      */}
      <section
        aria-label="About ServoMap"
        className="border-t border-line bg-bg pb-24 md:pb-0"
      >
        <div className="mx-auto max-w-4xl px-5 py-12">
          <h1 className="font-display text-display font-medium text-ink text-balance">
            ServoMap — live Australian fuel prices near you
          </h1>
          <p className="mt-4 text-ink-2 max-w-2xl">
            Compare real-time petrol and diesel prices across Australia on one
            map. ServoMap aggregates official state government fuel-price feeds
            so you can find the cheapest U91, E10, U95, U98 and Diesel near you.
            {liveText ? ` Live now in ${liveText}.` : ""}
          </p>

          {/* 州 hub 内链 — 真实数据驱动，给爬虫一条进入郊区图谱的路径 */}
          <nav aria-label="Browse by state" className="mt-6">
            <h2 className="caption mb-3">
              Browse fuel prices by state
            </h2>
            <ul className="flex flex-wrap gap-2">
              {live.map((s) => (
                <li key={s}>
                  <Link
                    href={`/fuel/${s}`}
                    className="btn btn-secondary"
                  >
                    {STATE_LABELS[s]} fuel prices
                  </Link>
                </li>
              ))}
            </ul>
          </nav>

          <p className="mt-8 text-body text-ink-3">
            Prices sourced from official state government fuel-price feeds.{" "}
            <Link href="/about" className="link">
              How ServoMap works
            </Link>
          </p>
        </div>
      </section>
    </>
  );
}
