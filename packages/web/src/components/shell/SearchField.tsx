"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Icon } from "@/components/ui/Icon";
import { cn } from "@/lib/utils";

interface SearchFieldProps {
  /** Query currently applied on the map page, shown so it can be edited or cleared. */
  initialQuery?: string;
  className?: string;
}

/**
 * Suburb / postcode search shared by every page. Submitting always lands on the map
 * with `?q=`, keeping the map page's other filters so a search refines rather than resets.
 */
export function SearchField({ initialQuery = "", className }: SearchFieldProps) {
  const router = useRouter();
  const [query, setQuery] = useState(initialQuery);
  const [appliedQuery, setAppliedQuery] = useState(initialQuery);
  const inputRef = useRef<HTMLInputElement>(null);

  // A new query applied elsewhere (map moved, search cleared) replaces the draft.
  if (initialQuery !== appliedQuery) {
    setAppliedQuery(initialQuery);
    setQuery(initialQuery);
  }

  // "/" focuses search from anywhere except another text field.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "/" || e.metaKey || e.ctrlKey) return;
      const tag = (e.target as HTMLElement | null)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;
      e.preventDefault();
      inputRef.current?.focus();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const go = (q: string) => {
    const params =
      window.location.pathname === "/"
        ? new URLSearchParams(window.location.search)
        : new URLSearchParams();
    if (q) params.set("q", q);
    else params.delete("q");
    const qs = params.toString();
    router.push(qs ? `/?${qs}` : "/");
  };

  return (
    <form
      role="search"
      className={cn(
        "flex items-center gap-2.5 h-9 px-3 rounded-2 border border-line bg-bg text-ink-3 focus-within:border-accent transition-colors duration-(--duration-fast)",
        className,
      )}
      onSubmit={(e) => {
        e.preventDefault();
        go(query.trim());
        inputRef.current?.blur();
      }}
    >
      <label htmlFor="suburb-search" className="sr-only">
        Search by suburb or postcode
      </label>
      <Icon name="search" />
      <input
        ref={inputRef}
        id="suburb-search"
        type="search"
        enterKeyHint="search"
        autoComplete="off"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Suburb or postcode"
        className="flex-1 min-w-0 bg-transparent text-body text-ink placeholder:text-ink-3 outline-none"
      />
      {query ? (
        <button
          type="button"
          className="icon-btn w-6 h-6"
          aria-label="Clear search"
          onClick={() => {
            setQuery("");
            go("");
          }}
        >
          <Icon name="close" size={14} />
        </button>
      ) : (
        <kbd className="hidden sm:inline-flex px-1.5 rounded-1 border border-line font-mono text-[11px] text-ink-3">
          /
        </kbd>
      )}
    </form>
  );
}
