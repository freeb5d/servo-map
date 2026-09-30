import { brandFamily } from "@servo-map/shared";
import { brandLogoImage } from "@/components/brand/logoImage";
import { cn } from "@/lib/utils";

/** Tile edge in px: sm in inline text and short lists, md in the ledger, lg on a station's header. */
export const BRAND_SEAL_SIZE = { sm: 22, md: 30, lg: 36 } as const;

interface BrandSealProps {
  /** Raw upstream brand name; resolved to its family here. */
  brand: string;
  size?: keyof typeof BRAND_SEAL_SIZE;
  className?: string;
}

/**
 * The brand mark (decision 0003): the brand's own logo on a white tile where one is bundled
 * (design/brand-logos), otherwise its monogram on a tile in `BRAND_FAMILIES[].mark` colours.
 * Members-only brands (Costco) get a dashed ring: you need a membership to fill up there.
 */
export function BrandSeal({ brand, size = "sm", className }: BrandSealProps) {
  const family = brandFamily(brand);
  const px = BRAND_SEAL_SIZE[size];
  const logo = brandLogoImage(family.id);
  const { background, foreground, stripe } = family.mark;

  return (
    <span
      role="img"
      aria-label={family.name}
      title={brand}
      style={{
        width: px,
        height: px,
        // Brand colours are data from @servo-map/shared, not theme tokens: signs look the same day and night.
        ...(logo ? null : { backgroundColor: background, color: foreground }),
      }}
      className={cn(
        "relative inline-grid shrink-0 place-items-center overflow-hidden rounded-[24%] leading-none select-none",
        logo && "border-[0.5px] border-brand-tile-line bg-brand-tile",
        family.group === "members" && "outline-1 outline-offset-[1.5px] outline-ink-3 outline-dashed",
        className,
      )}
    >
      {logo ? (
        // A plain <img> on the optimiser's URL: next/image would add script to every page for a 30px mark.
        // eslint-disable-next-line @next/next/no-img-element
        <img src={logo} alt="" width={px} height={px} loading="lazy" decoding="async" className="size-[80%] object-contain" />
      ) : (
        <>
          <span
            aria-hidden
            className="relative z-1 font-body font-bold tracking-[-0.01em]"
            style={{ fontSize: Math.round(px * (family.seal.length > 2 ? 0.3 : 0.38)) }}
          >
            {family.seal}
          </span>
          {stripe && (
            <span aria-hidden className="absolute inset-x-0 bottom-0 h-[14%]" style={{ backgroundColor: stripe }} />
          )}
        </>
      )}
    </span>
  );
}
