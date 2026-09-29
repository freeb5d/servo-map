import type { ReactNode } from "react";
import Link from "next/link";
import { MobileTabs } from "@/components/shell/MobileTabs";
import { cn, timeAgo } from "@/lib/utils";

interface DocPageProps {
  /** The TopBar, rendered by the caller because only some pages pass it a fuel switch. */
  topBar: ReactNode;
  /** Right-hand column (cycle card, nearby suburbs, map button); stacks under the content on phones. */
  aside?: ReactNode;
  children: ReactNode;
}

/**
 * Document layout for the indexable pages (v2): paper top bar, one readable column and an
 * optional 320px side column. Phones get the bottom tabs, so the page reserves their height.
 */
export function DocPage({ topBar, aside, children }: DocPageProps) {
  return (
    <div className="min-h-screen bg-bg pb-[calc(72px+env(safe-area-inset-bottom))] md:pb-0">
      {topBar}
      <div
        className={cn(
          "mx-auto grid gap-x-12 gap-y-6 px-4 pb-16 pt-6 md:px-12 md:pt-8",
          aside ? "max-w-[1104px] lg:grid-cols-[minmax(0,1fr)_320px]" : "max-w-3xl",
        )}
      >
        <main className="grid min-w-0 content-start gap-[22px]">{children}</main>
        {aside && <aside className="grid content-start gap-3.5">{aside}</aside>}
      </div>
      <MobileTabs active={null} />
    </div>
  );
}

interface Crumb {
  label: string;
  href?: string;
}

/** Breadcrumb trail; the last crumb is the current page. Mirrors the BreadcrumbList JSON-LD. */
export function Crumbs({ items }: { items: Crumb[] }) {
  return (
    <nav aria-label="Breadcrumb" className="flex flex-wrap gap-2 text-small text-ink-3">
      {items.map((item, i) => (
        <span key={item.label} className="flex gap-2">
          {i > 0 && <span aria-hidden="true">/</span>}
          {item.href ? (
            <Link href={item.href} className="hover:text-ink">
              {item.label}
            </Link>
          ) : (
            <span aria-current="page" className="text-ink-2">
              {item.label}
            </span>
          )}
        </span>
      ))}
    </nav>
  );
}

/** Page title in the display face. */
export function DocTitle({ children }: { children: ReactNode }) {
  return <h1 className="font-display text-[26px] font-medium leading-[1.3] text-balance md:text-display">{children}</h1>;
}

/** Source line under the content: where prices come from and how fresh they are. */
export function DocFooter({ lastUpdated }: { lastUpdated: string | null }) {
  return (
    <p className="border-t border-line-subtle pt-4 text-small text-ink-3">
      Prices sourced from state government fuel-price feeds.
      {lastUpdated ? ` Last updated ${timeAgo(lastUpdated)}.` : ""}{" "}
      <Link href="/about" className="link">
        How it works
      </Link>
      {" · "}
      <Link href="/privacy" className="link">
        Privacy
      </Link>
      {" · "}
      <Link href="/support" className="link">
        Support
      </Link>
    </p>
  );
}
