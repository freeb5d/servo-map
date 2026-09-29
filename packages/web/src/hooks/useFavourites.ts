"use client";

import { useCallback, useMemo, useSyncExternalStore } from "react";

const STORAGE_KEY = "servo-map:favourites";
const CHANGE_EVENT = "servo-map:favourites-change";

// Used only when localStorage is blocked (private mode, full quota): favourites still work for the
// life of the page, they just are not remembered.
let memory: string | null = null;

function readRaw(): string {
  try {
    return window.localStorage.getItem(STORAGE_KEY) ?? memory ?? "[]";
  } catch {
    return memory ?? "[]";
  }
}

function parse(raw: string): string[] {
  try {
    const value: unknown = JSON.parse(raw);
    return Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];
  } catch {
    // Corrupted value: treat as empty rather than break the page.
    return [];
  }
}

function writeIds(ids: string[]): void {
  const raw = JSON.stringify(ids);
  memory = raw;
  try {
    window.localStorage.setItem(STORAGE_KEY, raw);
  } catch {
    // Kept in memory above.
  }
  window.dispatchEvent(new Event(CHANGE_EVENT));
}

function subscribe(onChange: () => void): () => void {
  const onStorage = (e: StorageEvent) => {
    if (e.key === STORAGE_KEY) onChange();
  };
  window.addEventListener("storage", onStorage);
  window.addEventListener(CHANGE_EVENT, onChange);
  return () => {
    window.removeEventListener("storage", onStorage);
    window.removeEventListener(CHANGE_EVENT, onChange);
  };
}

/**
 * 收藏站点（无账号，纯 localStorage）。
 * 只存 station id —— 站点详情按需从已加载列表里取，避免存陈旧价格。
 *
 * Backed by useSyncExternalStore so `ids` and `ready` change in the same render: on the server
 * `raw` is null, on the client it is the stored JSON. Pages that show an empty state wait for
 * `ready` and never flash it before the saved ids arrive.
 */
export function useFavourites() {
  const raw = useSyncExternalStore(subscribe, readRaw, () => null);
  const ready = raw !== null;
  const ids = useMemo(() => (raw === null ? [] : parse(raw)), [raw]);

  // 用 Set 做 O(1) 判定，避免每张卡片 includes 全量数组
  const idSet = useMemo(() => new Set(ids), [ids]);

  const isFavourite = useCallback((id: string) => idSet.has(id), [idSet]);

  const toggle = useCallback((id: string) => {
    const current = parse(readRaw());
    writeIds(current.includes(id) ? current.filter((x) => x !== id) : [...current, id]);
  }, []);

  return { favouriteIds: ids, isFavourite, toggle, count: ids.length, ready };
}
