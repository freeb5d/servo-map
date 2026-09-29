"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import type { StationWithDistance } from "@servo-map/shared";
import { Crumbs, DocFooter, DocPage, DocTitle } from "@/components/doc/DocPage";
import { TierLabel } from "@/components/ui/TierLabel";
import { TopBar } from "@/components/shell/TopBar";
import { StaleBanner } from "@/components/stations/StaleBanner";
import { BrandSeal } from "@/components/ui/BrandSeal";
import { Card } from "@/components/trends/Card";
import { useFuelPreference } from "@/hooks/useFuelPreference";
import { cn, formatPriceCents, getFuelPrice, timeAgo } from "@/lib/utils";

interface NearbySuburb {
  slug: string;
  name: string;
  stationCount: number;
  /** Lowest U91 in that suburb, cents; null when none of its stations sells U91. */
  minU91: number | null;
}

interface Props {
  suburbName: string;
  stateName: string;
  /** 小写州码，用于内链（/fuel/<state> 与 /fuel/<state>/<suburb>） */
  stateSlug: string;
  stations: StationWithDistance[];
  /** 该州数据最后更新时间（ISO 串），来自 metadata 端点 */
  lastUpdated: string | null;
  /** One-paragraph summary of the page's real numbers, shown under the title. */
  lede: string;
  /** 模板化正文段落（由真实数据驱动） */
  prose: string[];
  /** FAQ 问答（同时驱动 FAQPage 结构化数据） */
  faqs: { q: string; a: string }[];
  /** 邻近郊区交叉链接 */
  nearby: NearbySuburb[];
  /** 预渲染的州级价格趋势区块（服务端组件），无数据时为 null */
  priceTrend?: ReactNode;
  /** Pre-rendered state cycle card for the side column; null without history. */
  cycleCard?: ReactNode;
}

const TH = "px-3.5 py-2.5 text-left text-small font-normal text-ink-3";

export function SuburbPageClient({
  suburbName,
  stateName,
  stateSlug,
  stations,
  lastUpdated,
  lede,
  prose,
  faqs,
  nearby,
  priceTrend,
  cycleCard,
}: Props) {
  const [fuel, setFuel] = useFuelPreference();

  // Stations without a price for the chosen fuel go last, in their original order.
  const sorted = [...stations].sort((a, b) => {
    const pa = getFuelPrice(a.prices, fuel)?.price ?? Infinity;
    const pb = getFuelPrice(b.prices, fuel)?.price ?? Infinity;
    return pa - pb;
  });
  const cheapestId = sorted[0] && getFuelPrice(sorted[0].prices, fuel) ? sorted[0].id : null;

  return (
    <DocPage
      topBar={<TopBar active={null} fuel={fuel} onFuelChange={setFuel} />}
      aside={
        <>
          {cycleCard}
          {nearby.length > 0 && (
            <Card label="Nearby suburbs" aside="lowest U91">
              <ul>
                {nearby.map((n) => (
                  <li key={n.slug} className="flex items-center justify-between gap-2 border-b border-line-subtle py-[7px] last:border-b-0">
                    <Link href={`/fuel/${stateSlug}/${n.slug}`} className="link">
                      {n.name}
                    </Link>
                    {n.minU91 !== null ? (
                      <span className="font-display text-body font-semibold tabular-nums">{formatPriceCents(n.minU91)}</span>
                    ) : (
                      <span className="text-small text-ink-3">{n.stationCount} st.</span>
                    )}
                  </li>
                ))}
              </ul>
            </Card>
          )}
          <Link href={`/?q=${encodeURIComponent(suburbName)}`} className="btn btn-primary">
            Open {suburbName} on the map
          </Link>
        </>
      }
    >
      <Crumbs items={[{ label: stateName, href: `/fuel/${stateSlug}` }, { label: suburbName }]} />
      <DocTitle>
        Fuel prices in {suburbName}, {stateName}
      </DocTitle>
      <p className="max-w-[36em] text-body text-ink-2">{lede}</p>
      {lastUpdated && <StaleBanner lastUpdated={lastUpdated} className="max-w-md" />}

      <div className="overflow-x-auto rounded-3 border border-line-subtle bg-surface animate-rise-in">
        <table className="w-full min-w-[420px] border-collapse text-body">
          <caption className="sr-only">
            {fuel} prices at {suburbName} stations, cheapest first
          </caption>
          <thead>
            <tr>
              <th className={cn(TH, "w-12")} aria-label="Brand" />
              <th className={TH}>Station</th>
              <th className={cn(TH, "text-right")}>{fuel}</th>
              <th className={cn(TH, "text-right max-sm:hidden")}>Updated</th>
            </tr>
          </thead>
          <tbody>
            {sorted.map((station) => {
              const fp = getFuelPrice(station.prices, fuel);
              const isCheapest = station.id === cheapestId;
              return (
                <tr key={station.id} className={cn("border-t border-line-subtle", isCheapest && "bg-price-cheap-soft")}>
                  <td className="px-3.5 py-3">
                    <BrandSeal brand={station.brand} />
                  </td>
                  <td className="px-3.5 py-3">
                    <Link href={`/station/${station.id}`} className="font-medium hover:underline">
                      {station.name}
                    </Link>
                    {isCheapest && <TierLabel tier="cheap" className="ml-2.5">Cheapest</TierLabel>}
                    <div className="text-small text-ink-3">{station.address}</div>
                  </td>
                  <td className="px-3.5 py-3 text-right">
                    {fp ? (
                      <span className="font-display text-[19px] font-semibold tabular-nums">{formatPriceCents(fp.price)}</span>
                    ) : (
                      <span className="text-ink-3">&mdash;</span>
                    )}
                  </td>
                  <td className="px-3.5 py-3 text-right text-small text-ink-3 max-sm:hidden">{fp ? timeAgo(fp.updated_at) : ""}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* 州级价格趋势 — 数据按州采集，标注为全州走势而非本郊区 */}
      {priceTrend}

      {/* 模板化正文：可索引、由真实数据驱动，清除 thin-content */}
      {prose.length > 0 && (
        <section className="grid max-w-[40em] gap-3">
          <h2 className="caption">About fuel prices in {suburbName}</h2>
          {prose.map((para, i) => (
            <p key={i} className="text-body text-ink-2">
              {para}
            </p>
          ))}
        </section>
      )}

      {/* FAQ — 可见问答，同时镜像 FAQPage 结构化数据 */}
      {faqs.length > 0 && (
        <section className="grid gap-3">
          <h2 className="caption">{suburbName} fuel price FAQ</h2>
          <dl className="grid gap-3">
            {faqs.map((f, i) => (
              <div key={i} className="rounded-3 border border-line-subtle bg-surface px-5 py-4">
                <dt className="text-body font-medium text-ink">{f.q}</dt>
                <dd className="mt-2 text-body text-ink-2">{f.a}</dd>
              </div>
            ))}
          </dl>
        </section>
      )}

      <DocFooter lastUpdated={lastUpdated} />
    </DocPage>
  );
}
