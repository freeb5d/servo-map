"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Pixel width of an element, kept current with ResizeObserver. Charts draw in real pixels so
 * their labels stay at a fixed, readable size instead of shrinking with a scaled viewBox.
 */
export function useElementWidth<T extends HTMLElement>(fallback: number): [React.RefObject<T | null>, number] {
  const ref = useRef<T | null>(null);
  const [width, setWidth] = useState(fallback);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) => {
      const next = Math.floor(entry.contentRect.width);
      if (next > 0) setWidth(next);
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return [ref, width];
}
