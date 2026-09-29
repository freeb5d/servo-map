"use client";

import Link from "next/link";
import { brandFamily, type StationWithDistance } from "@servo-map/shared";
import { Crumbs, DocFooter, DocPage, DocTitle } from "@/components/doc/DocPage";
import { TopBar } from "@/components/shell/TopBar";
import { FreshnessBadge } from "@/components/stations/FreshnessBadge";
import { ShareButton } from "@/components/stations/ShareButton";
import { StaleBanner } from "@/components/stations/StaleBanner";
import { BrandSeal } from "@/components/ui/BrandSeal";
import { Icon } from "@/components/ui/Icon";
import { useFavourites } from "@/hooks/useFavourites";
import { formatPriceCents, timeAgo } from "@/lib/utils";
import { formatAddress } from "@/lib/place-names";

interface Props {
  station: StationWithDistance;
  /** 该州数据最后更新时间（ISO 串），来自 metadata 端点 */
  lastUpdated: string | null;
  /** 站点所属郊区页链接，例如 /fuel/nsw/umina-beach */
  suburbHref: string;
}

export function StationPageClient({ station, lastUpdated, suburbHref }: Props) {
  const { isFavourite, toggle } = useFavourites();
  const saved = isFavourite(station.id);
  const family = brandFamily(station.brand);
  const directionsUrl = `https://www.google.com/maps/dir/?api=1&destination=${station.lat},${station.lng}`;

  return (
    <DocPage topBar={<TopBar active={null} />}>
      <Crumbs
        items={[
          { label: station.state.toUpperCase(), href: `/fuel/${station.state.toLowerCase()}` },
          { label: station.suburb, href: suburbHref },
          { label: station.name },
        ]}
      />

      <header className="grid gap-2 animate-rise-in">
        <div className="flex items-center gap-2">
          <BrandSeal brand={station.brand} size="lg" />
          <span className="caption">
            {family.name}
          </span>
        </div>
        <DocTitle>{station.name}</DocTitle>
        <p className="text-body text-ink-2">
          {formatAddress(station)}
        </p>
        {lastUpdated && (
          <div>
            <FreshnessBadge lastUpdated={lastUpdated} />
          </div>
        )}
        {lastUpdated && <StaleBanner lastUpdated={lastUpdated} className="max-w-md" />}
      </header>

      <section className="grid gap-3 animate-rise-in">
        <h2 className="caption">Current prices</h2>
        {station.prices.length === 0 ? (
          <p className="text-body text-ink-2">This station has not reported a price yet.</p>
        ) : (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {station.prices.map((fp) => (
              <div key={fp.fuel} className="grid gap-1 rounded-3 border border-line-subtle bg-surface p-4">
                <span className="text-small font-medium text-ink-2">{fp.fuel}</span>
                <span className="font-display text-[30px] font-semibold leading-[1.1] tabular-nums">
                  {formatPriceCents(fp.price)}
                  <span className="ml-0.5 font-body text-small font-normal text-ink-3">&cent;/L</span>
                </span>
                <span className="text-small text-ink-3">{timeAgo(fp.updated_at)}</span>
              </div>
            ))}
          </div>
        )}
      </section>

      <div className="flex flex-wrap items-center gap-3 animate-rise-in">
        <a href={directionsUrl} target="_blank" rel="noopener noreferrer" className="btn btn-primary">
          <Icon name="directions" />
          Get Directions
        </a>
        <button
          type="button"
          aria-pressed={saved}
          onClick={() => toggle(station.id)}
          className="btn btn-secondary"
        >
          <Icon name="bookmark" filled={saved} />
          {saved ? "Saved" : "Save"}
        </button>
        <ShareButton title={`${station.brand} ${station.name} — ServoMap`} path={`/station/${station.id}`} />
      </div>

      <Link href={suburbHref} className="link inline-flex items-center gap-1.5 justify-self-start text-body">
        Compare all fuel in {station.suburb}
        <Icon name="arrow-right" size={14} />
      </Link>

      <DocFooter lastUpdated={lastUpdated} />
    </DocPage>
  );
}
