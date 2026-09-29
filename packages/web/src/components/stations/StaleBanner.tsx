"use client";

import { cn, isStale, timeAgo } from "@/lib/utils";
import { Icon } from "@/components/ui/Icon";

interface StaleBannerProps {
  /** 数据最后更新时间（ISO 串），为空则不渲染 */
  lastUpdated: string | null | undefined;
  className?: string;
}

/**
 * 数据过期（> ~12h）告警横幅。只在确实过期时渲染，避免在正常情况下打扰用户。
 */
export function StaleBanner({ lastUpdated, className }: StaleBannerProps) {
  if (!lastUpdated || !isStale(lastUpdated)) return null;

  return (
    <div
      role="status"
      className={cn(
        "flex items-start gap-3 rounded-2 bg-price-mid-soft px-3.5 py-3 text-small text-ink",
        className,
      )}
    >
      <Icon name="warning" size={14} className="shrink-0 mt-[3px] text-price-mid" />
      <span>
        Prices may be out of date — last updated {timeAgo(lastUpdated)}.
      </span>
    </div>
  );
}
