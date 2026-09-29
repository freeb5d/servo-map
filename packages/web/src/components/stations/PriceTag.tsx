"use client";

import {
  cn,
  priceColorClass,
  formatPriceCents,
  priceTier,
  TIER_LABELS,
} from "@/lib/utils";
import { usePriceRange } from "@/providers/PriceRangeProvider";

interface PriceTagProps {
  cents: number;
  size?: "sm" | "md" | "lg" | "xl";
  showUnit?: boolean;
  /** 在价格旁渲染可见的档位文字（Cheap/Fair/Pricey），作为颜色之外的信号 */
  showTier?: boolean;
  /** 档位标签换行显示在价格下方并右对齐（列表行用） */
  stacked?: boolean;
  className?: string;
}

const SIZE_CLASSES = {
  sm: "text-lead",
  md: "text-price",
  lg: "text-heading",
  xl: "text-price-xl",
};

export function PriceTag({
  cents,
  size = "md",
  showUnit = true,
  showTier = false,
  stacked = false,
  className,
}: PriceTagProps) {
  const range = usePriceRange();
  const tier = priceTier(cents, range);
  const tierLabel = TIER_LABELS[tier];

  return (
    <span
      className={cn(
        "inline-flex",
        stacked ? "flex-col items-end gap-0.5" : "items-baseline gap-2",
        className,
      )}
    >
      {/* 价格数字保持 ink：档位只由标签与 ■ 表达 */}
      <span
        className={cn(
          "font-display font-semibold tabular-nums text-ink",
          SIZE_CLASSES[size],
        )}
      >
        {formatPriceCents(cents)}
        {showUnit && (
          <span className="text-ink-3 font-body font-normal text-[0.42em] ml-0.5">
            ¢/L
          </span>
        )}
      </span>
      {showTier ? (
        // 可见档位标签：颜色之外的文字信号（WCAG 1.4.1）
        <span className="inline-flex items-center gap-1.5">
          <span
            aria-hidden="true"
            className={cn("mark-square", priceColorClass(cents, range))}
          />
          <span className="caption">{tierLabel}</span>
        </span>
      ) : (
        // 不显示可见标签时，仍向屏幕阅读器/色觉用户暴露档位，确保价格不仅靠颜色区分
        <span className="sr-only"> — {tierLabel} relative to nearby</span>
      )}
    </span>
  );
}
