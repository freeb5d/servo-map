"use client";

import { useEffect, useState } from "react";

const TICK_MS = 60_000;

/** Current time in ms, refreshed every minute so "4m ago" labels do not go stale. */
export function useNow(): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), TICK_MS);
    return () => window.clearInterval(id);
  }, []);
  return now;
}
