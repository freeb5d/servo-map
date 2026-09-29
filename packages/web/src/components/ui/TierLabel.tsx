import { TIER_LABELS, TIER_TEXT_CLASS, cn, type PriceTier } from "@/lib/utils";

interface TierLabelProps {
  tier: PriceTier;
  /** Overrides the default word (Cheap, Fair, Pricey), e.g. "Cheapest". */
  children?: string;
  className?: string;
}

/** Price tier as a plain coloured word; the word keeps the meaning readable without colour. */
export function TierLabel({ tier, children, className }: TierLabelProps) {
  return (
    <span className={cn("text-small font-medium", TIER_TEXT_CLASS[tier], className)}>
      {children ?? TIER_LABELS[tier]}
    </span>
  );
}
