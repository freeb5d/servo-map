const ITEMS = [
  { label: "Cheap", tone: "text-price-cheap" },
  { label: "Fair", tone: "text-price-mid" },
  { label: "Pricey", tone: "text-price-expensive" },
] as const;

/**
 * 价格档位图例 — 颜色之外再给文字标签，避免色觉依赖（WCAG 1.4.1）。
 * 桌面端常驻；移动端被底部抽屉遮挡，故 md 以下隐藏，列表是其无障碍替代路径。
 */
export function MapLegend() {
  return (
    <div
      className="floating hidden md:block absolute bottom-6 left-4 z-10 px-3 py-2 pointer-events-none"
      aria-hidden="true"
    >
      <p className="caption mb-1.5">Compared with nearby</p>
      <ul className="flex items-center gap-4">
        {ITEMS.map(({ label, tone }) => (
          <li key={label} className="flex items-center gap-1.5">
            <span className={`mark-square ${tone}`} />
            <span className="text-small text-ink-2">{label}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
