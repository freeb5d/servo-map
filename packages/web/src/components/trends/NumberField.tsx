"use client";

import { useState } from "react";

interface NumberFieldProps {
  label: string;
  value: number;
  min: number;
  max: number;
  suffix?: string;
  onCommit: (value: number) => void;
}

/**
 * Numeric input that lets the viewer clear and retype: the draft text is only committed when it
 * parses inside the allowed range, and snaps back to the last good value on blur.
 */
export function NumberField({ label, value, min, max, suffix, onCommit }: NumberFieldProps) {
  const [draft, setDraft] = useState<string | null>(null);

  return (
    <label className="inline-flex items-center gap-2 text-body">
      <span className="text-ink-2">{label}</span>
      <span className="inline-flex h-[30px] min-w-16 items-center gap-1 rounded-2 border border-line bg-bg px-2.5">
        <input
          type="text"
          inputMode="decimal"
          value={draft ?? String(value)}
          aria-label={label}
          onChange={(e) => {
            setDraft(e.target.value);
            const n = Number(e.target.value);
            if (e.target.value.trim() !== "" && Number.isFinite(n) && n >= min && n <= max) onCommit(n);
          }}
          onBlur={() => setDraft(null)}
          className="w-12 bg-transparent font-display font-semibold tabular-nums text-ink outline-none"
        />
        {suffix && <span className="text-small text-ink-3">{suffix}</span>}
      </span>
    </label>
  );
}
