import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface FilterChipProps {
  on: boolean;
  onClick: () => void;
  children: ReactNode;
}

/** Toggle chip: ink fill when on, paper with a hairline when off. */
export function FilterChip({ on, onClick, children }: FilterChipProps) {
  return (
    <button
      type="button"
      aria-pressed={on}
      onClick={onClick}
      className={cn(
        "inline-flex h-6 items-center gap-1.5 whitespace-nowrap rounded-1 border px-2 text-small transition-colors duration-(--duration-fast)",
        on
          ? "border-accent bg-accent text-on-accent"
          : "border-line bg-surface text-ink-2 hover:bg-wash hover:text-ink",
      )}
    >
      {children}
    </button>
  );
}
