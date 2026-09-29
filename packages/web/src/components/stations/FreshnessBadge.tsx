"use client";

import { cn, timeAgo } from "@/lib/utils";

interface FreshnessBadgeProps {
  /** 数据最后更新时间（ISO 串） */
  lastUpdated: string;
  /** 紧凑模式：去掉前缀文字，只显示相对时间 */
  compact?: boolean;
  className?: string;
}

type Freshness = {
  label: string;
  /** Tier text colour; drives the ■ mark via currentColor. */
  tone: string;
};

/**
 * 把更新时间映射到新鲜度分级：
 * - Live   < 1h   绿
 * - Recent < 12h  黄
 * - Stale  >= 12h 红
 * 标签本身保持中性，颜色只出现在 ■ 上。
 */
function freshnessFor(dateStr: string): Freshness {
  const diffHr = (Date.now() - new Date(dateStr).getTime()) / 3_600_000;
  if (diffHr < 1) return { label: "Live", tone: "text-price-cheap" };
  if (diffHr < 12) return { label: "Recent", tone: "text-price-mid" };
  return { label: "Stale", tone: "text-price-expensive" };
}

/** 中性小标签 + 分级色 ■，反映数据新鲜度。 */
export function FreshnessBadge({
  lastUpdated,
  compact = false,
  className,
}: FreshnessBadgeProps) {
  const fresh = freshnessFor(lastUpdated);
  const rel = timeAgo(lastUpdated);

  return (
    <span
      className={cn(
        "inline-flex items-center gap-2 rounded-1 border border-line-subtle bg-surface px-2.5 py-[3px] text-small text-ink-2",
        className,
      )}
      title={`Data updated ${rel}`}
    >
      <span aria-hidden="true" className={cn("mark-square", fresh.tone)} />
      {compact ? rel : `${fresh.label}, ${rel}`}
    </span>
  );
}
