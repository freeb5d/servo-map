/** Static placeholder rows while the first load runs; a slow breathe, no shimmer. */
export function LedgerSkeleton({ rows = 7 }: { rows?: number }) {
  return (
    <div aria-hidden="true" className="animate-breathe">
      {Array.from({ length: rows }).map((_, i) => (
        <div
          key={i}
          className="grid grid-cols-[18px_30px_1fr_auto] items-center gap-2.5 border-b border-line-subtle px-5 py-[11px]"
        >
          <div className="h-3 w-3 rounded-1 bg-wash" />
          <div className="h-[18px] w-[26px] rounded-1 bg-wash" />
          <div className="grid gap-1.5">
            <div className="h-3.5 w-3/4 rounded-1 bg-wash" />
            <div className="h-3 w-1/2 rounded-1 bg-wash" />
          </div>
          <div className="grid justify-items-end gap-1.5">
            <div className="h-5 w-14 rounded-1 bg-wash" />
            <div className="h-2.5 w-9 rounded-1 bg-wash" />
          </div>
        </div>
      ))}
    </div>
  );
}
