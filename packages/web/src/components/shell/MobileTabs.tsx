"use client";

import Link from "next/link";
import { Icon } from "@/components/ui/Icon";
import { cn } from "@/lib/utils";
import { SECTIONS, type Section } from "./nav";

/** Bottom tab bar on phones, mirroring the iOS tabs. Hidden from md up, where TopBar carries the sections. */
export function MobileTabs({ active }: { active: Section | null }) {
  return (
    <nav
      aria-label="Sections"
      className="md:hidden fixed inset-x-0 bottom-0 z-40 flex justify-around bg-surface border-t border-line pt-1.5 pb-[max(6px,env(safe-area-inset-bottom))]"
    >
      {SECTIONS.map((s) => (
        <Link
          key={s.id}
          href={s.href}
          aria-current={active === s.id ? "page" : undefined}
          className={cn(
            "grid justify-items-center gap-0.5 px-4 py-1 text-[10px]",
            active === s.id ? "text-ink font-bold" : "text-ink-3",
          )}
        >
          <Icon name={s.icon} size={18} filled={s.icon === "bookmark" && active === s.id} />
          {s.label}
        </Link>
      ))}
    </nav>
  );
}
