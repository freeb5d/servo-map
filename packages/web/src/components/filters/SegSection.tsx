import type { ReactNode } from "react";

interface Option<T> {
  value: T;
  label: string;
}

interface SegSectionProps<T> {
  title: string;
  hint?: ReactNode;
  options: Option<T>[];
  value: T;
  onChange: (value: T) => void;
}

/** A labelled segmented control row of the filter panel (distance, price age). */
export function SegSection<T extends string | number | undefined>({
  title,
  hint,
  options,
  value,
  onChange,
}: SegSectionProps<T>) {
  return (
    <div className="grid gap-2 border-b border-line-subtle py-3">
      <div className="flex items-baseline justify-between">
        <span className="caption">{title}</span>
        {hint && <span className="text-[11px] text-ink-3">{hint}</span>}
      </div>
      <div role="group" aria-label={title} className="seg w-max max-w-full">
        {options.map((o) => (
          <button
            key={String(o.value ?? "any")}
            type="button"
            aria-pressed={o.value === value}
            onClick={() => onChange(o.value)}
            className="seg-item"
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
  );
}
