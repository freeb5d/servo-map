import { brandFamily } from "@servo-map/shared";
import { cn } from "@/lib/utils";

interface BrandSealProps {
  /** Raw upstream brand name; resolved to its family here. */
  brand: string;
  size?: "sm" | "lg";
  className?: string;
}

/** The brand seal (判子): a monogram of the brand family, used instead of third-party logos. */
export function BrandSeal({ brand, size = "sm", className }: BrandSealProps) {
  const family = brandFamily(brand);
  return (
    <span
      role="img"
      aria-label={family.name}
      title={brand}
      className={cn(
        "inline-grid place-items-center shrink-0 rounded-1 border border-ink-2 bg-surface font-body font-bold text-ink leading-none tracking-[0.06em]",
        size === "sm" ? "min-w-[26px] h-[18px] px-1 text-[9px]" : "min-w-[38px] h-[26px] px-1.5 text-[11px]",
        // Dashed edge marks brands that need a membership (Costco).
        family.group === "members" && "border-dashed",
        className,
      )}
    >
      {family.seal}
    </span>
  );
}
