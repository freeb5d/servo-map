"use client";

import Link from "next/link";
import type { FuelType } from "@servo-map/shared";
import { suburbStats, type SuburbStat } from "@/lib/aggregate";
import { suburbToSlug } from "@/lib/seo";
import { cn, formatPriceCents } from "@/lib/utils";
import { Card } from "./Card";
import { NearGate } from "./NearGate";
import { NEAR_RADIUS_KM, type NearYou } from "./useNearYou";

interface SuburbTablesProps {
  near: NearYou;
  fuel: FuelType;
  className?: string;
}

const LIST_SIZE = 5;

/** Cheapest and dearest suburbs among the nearby stations, each linking to its suburb page. */
export function SuburbTables({ near, fuel, className }: SuburbTablesProps) {
  return (
    <Card label="Suburbs today" aside={`lowest ${fuel}, within ${NEAR_RADIUS_KM} km`} className={className}>
      <NearGate near={near} fuel={fuel}>
        {(stations) => {
          const ranked = suburbStats(stations, fuel);
          const cheapest = ranked.slice(0, LIST_SIZE);
          // Never repeat a suburb in both lists when few are in range.
          const dearest = ranked.slice(Math.max(LIST_SIZE, ranked.length - LIST_SIZE)).reverse();
          return (
            <div className="grid gap-4 md:grid-cols-2">
              <SuburbTable title="Cheapest suburbs" rows={cheapest} highlightFirst />
              {dearest.length > 0 ? (
                <SuburbTable title="Dearest suburbs" rows={dearest} />
              ) : (
                <p className="text-body text-ink-2">Too few suburbs in range to rank the dearest.</p>
              )}
            </div>
          );
        }}
      </NearGate>
    </Card>
  );
}

function SuburbTable({ title, rows, highlightFirst = false }: { title: string; rows: SuburbStat[]; highlightFirst?: boolean }) {
  const th = "px-2.5 py-2 text-small font-normal text-ink-3";
  return (
    <table className="w-full border-collapse text-body">
      <thead>
        <tr>
          <th className={cn(th, "text-left")}>{title}</th>
          <th className={cn(th, "text-right")}>Low</th>
          <th className={cn(th, "text-right")}>St.</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((row, i) => (
          <tr
            key={`${row.state}-${row.suburb}`}
            className={cn("border-t border-line-subtle", highlightFirst && i === 0 && "bg-price-cheap-soft")}
          >
            <td className="px-2.5 py-2">
              <Link href={`/fuel/${row.state}/${suburbToSlug(row.suburb)}`} className="link">
                {row.suburb}
              </Link>
            </td>
            <td className="px-2.5 py-2 text-right font-display font-semibold tabular-nums">{formatPriceCents(row.min)}</td>
            <td className="px-2.5 py-2 text-right tabular-nums text-ink-2">{row.count}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
