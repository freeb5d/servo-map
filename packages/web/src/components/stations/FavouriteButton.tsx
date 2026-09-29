"use client";

import { cn } from "@/lib/utils";
import { Icon } from "@/components/ui/Icon";

interface FavouriteButtonProps {
  active: boolean;
  onToggle: () => void;
  size?: "sm" | "md";
  className?: string;
}

/**
 * 收藏书签按钮。受控（active）+ 上报点击（onToggle）。
 * 内部 stopPropagation，避免在列表行内触发行自身的点击。
 */
export function FavouriteButton({
  active,
  onToggle,
  size = "sm",
  className,
}: FavouriteButtonProps) {
  return (
    <button
      type="button"
      onClick={(e) => {
        e.stopPropagation();
        onToggle();
      }}
      aria-pressed={active}
      aria-label={active ? "Remove from saved" : "Save station"}
      className={cn("icon-btn", active && "text-ink", className)}
    >
      <Icon name="bookmark" size={size === "sm" ? 16 : 18} filled={active} />
    </button>
  );
}
