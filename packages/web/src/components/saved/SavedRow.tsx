import Link from "next/link";
import type { FuelType, Station } from "@servo-map/shared";
import { TierLabel } from "@/components/ui/TierLabel";
import { BrandSeal } from "@/components/ui/BrandSeal";
import { Icon } from "@/components/ui/Icon";
import { changeLine } from "@/lib/saved";
import type { PriceMark } from "@/lib/saved";
import { cn, formatPriceCents, getFuelPrice, type PriceTier } from "@/lib/utils";

interface SavedRowProps {
  rank: number;
  station: Station;
  fuel: FuelType;
  /** The price seen at the previous visit; undefined on the first visit. */
  previous: PriceMark | undefined;
  /** Null when too few stations are saved for a tier to mean anything. */
  tier: PriceTier | null;
  onRemove: () => void;
}

const ROW = "grid grid-cols-[18px_30px_1fr_auto_32px] items-center gap-2.5 border-b border-line-subtle px-4 py-[11px] last:border-b-0 md:px-5";
const TONE = { cheap: "text-price-cheap", expensive: "text-price-expensive", none: "text-ink-3" } as const;

/** One saved station: rank, seal, name, how its price moved, today's price and a remove button. */
export function SavedRow({ rank, station, fuel, previous, tier, onRemove }: SavedRowProps) {
  const price = getFuelPrice(station.prices, fuel);
  const change = price ? changeLine(previous, price.price, new Date()) : null;

  return (
    <li className={ROW}>
      <span className="font-display text-body tabular-nums text-ink-3">{rank}</span>
      <BrandSeal brand={station.brand} />
      <div className="min-w-0">
        <Link href={`/station/${station.id}`} className="block truncate font-medium hover:underline">
          {station.name}
        </Link>
        <div className={cn("truncate text-small", change ? TONE[change.tone] : "text-ink-3")}>
          {change ? change.text : `No ${fuel} price reported`}
        </div>
      </div>
      <div className="grid justify-items-end">
        {price ? (
          <>
            <span className="font-display text-[19px] font-semibold leading-[1.2] tabular-nums">
              {formatPriceCents(price.price)}
            </span>
            {tier && <TierLabel tier={tier} />}
          </>
        ) : (
          <span className="text-ink-3">&mdash;</span>
        )}
      </div>
      <button type="button" className="icon-btn" aria-label={`Remove ${station.name} from saved`} onClick={onRemove}>
        <Icon name="close" />
      </button>
    </li>
  );
}

/** A saved id that could not be shown: delisted upstream, or a request that failed. */
export function UnavailableRow({ id, status, onRemove }: { id: string; status: "missing" | "error"; onRemove: () => void }) {
  return (
    <li className={cn(ROW, "grid-cols-[1fr_32px]")}>
      <div className="min-w-0">
        <div className="font-medium">
          {status === "missing" ? "This station is no longer reported." : "Couldn’t load this station."}
        </div>
        <div className="truncate text-small text-ink-3">
          {status === "missing" ? "Its state feed has dropped it." : "Reload to try again."} ({id})
        </div>
      </div>
      <button type="button" className="icon-btn" aria-label={`Remove ${id} from saved`} onClick={onRemove}>
        <Icon name="close" />
      </button>
    </li>
  );
}
