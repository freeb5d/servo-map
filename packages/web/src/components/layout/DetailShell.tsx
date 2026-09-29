"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { cn } from "@/lib/utils";

interface DetailShellProps {
  /** Right-hand column on desktop; full-height sheet over the map on phones. */
  variant: "drawer" | "sheet";
  label: string;
  /** Changes when the content is about another station, so focus follows it. */
  contentKey: string;
  onClose: () => void;
  children: ReactNode;
}

/** Frame for station detail: moves focus in when it opens or changes and closes on Esc. */
export function DetailShell({ variant, label, contentKey, onClose, children }: DetailShellProps) {
  const ref = useRef<HTMLDivElement>(null);
  const closeRef = useRef(onClose);
  useEffect(() => {
    closeRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    ref.current?.focus({ preventScroll: true });
  }, [contentKey]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeRef.current();
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  return (
    <div
      ref={ref}
      role={variant === "sheet" ? "dialog" : "complementary"}
      aria-label={label}
      tabIndex={-1}
      className={cn(
        "overflow-y-auto bg-surface outline-none animate-rise-in",
        variant === "drawer"
          ? "hidden w-[380px] shrink-0 border-l border-line md:block"
          : "absolute inset-0 z-30 rounded-t-[12px] border-t border-line md:hidden",
      )}
    >
      {variant === "sheet" && <span aria-hidden="true" className="mx-auto mt-2 block h-[3px] w-8 bg-line" />}
      {children}
    </div>
  );
}
