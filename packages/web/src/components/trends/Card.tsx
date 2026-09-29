import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface CardProps {
  /** Short sentence-case name of the module. */
  label: string;
  /** Right-aligned aside in the header: scope, unit or caveat. */
  aside?: ReactNode;
  className?: string;
  children: ReactNode;
}

/** A trends module: separated by a hairline and space, not boxed (素: no card soup). */
export function Card({ label, aside, className, children }: CardProps) {
  return (
    <section
      className={cn(
        "grid content-start gap-3 min-w-0 border-t border-line pt-4 pb-2",
        className,
      )}
    >
      <div className="flex items-baseline justify-between gap-2">
        <h2 className="text-body font-medium text-ink">{label}</h2>
        {aside && <span className="text-small text-ink-3 text-right">{aside}</span>}
      </div>
      {children}
    </section>
  );
}

interface ModuleNoteProps {
  /** One sentence saying what is going on and, if it helps, what to do. */
  children: ReactNode;
  /** Pulses while a request is in flight. */
  busy?: boolean;
  action?: ReactNode;
}

/** Loading, empty and error state for a module: a sentence, never a blank box. */
export function ModuleNote({ children, busy = false, action }: ModuleNoteProps) {
  return (
    <div role={busy ? "status" : undefined} className="grid justify-items-start gap-1.5 py-3">
      <p className={cn("text-body text-ink-2", busy && "animate-breathe")}>{children}</p>
      {action}
    </div>
  );
}
