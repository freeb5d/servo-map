import type { ReactNode } from "react";

interface NoticeProps {
  title?: string;
  children: ReactNode;
  action?: { label: string; onClick: () => void; primary?: boolean };
}

/** An in-column message: request failed, search found nothing, no coverage, or filters too tight. */
export function LedgerNotice({ title, children, action }: NoticeProps) {
  return (
    <div className="grid gap-2 border-b border-line-subtle px-5 py-4 animate-fade-in">
      {title && <p className="font-medium text-ink">{title}</p>}
      <p className="text-small text-ink-2">{children}</p>
      {action && (
        <div>
          <button
            type="button"
            onClick={action.onClick}
            className={`btn btn-sm ${action.primary ? "btn-primary" : "btn-secondary"}`}
          >
            {action.label}
          </button>
        </div>
      )}
    </div>
  );
}
