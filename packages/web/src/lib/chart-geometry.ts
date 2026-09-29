/** A point in SVG pixels. */
export interface Point {
  x: number;
  y: number;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] as const;
const DAY_MS = 86_400_000;

/**
 * SVG path through the points as a monotone cubic curve (Fritsch–Carlson), so the line reads
 * smooth like the evilcharts reference but never overshoots a day's real value.
 */
export function smoothPath(points: readonly Point[]): string {
  if (points.length === 0) return "";
  if (points.length === 1) return `M${points[0].x},${points[0].y}`;
  const n = points.length;
  const dx = points.slice(1).map((p, i) => p.x - points[i].x);
  const slope = points.slice(1).map((p, i) => (dx[i] === 0 ? 0 : (p.y - points[i].y) / dx[i]));
  const tangent = points.map((_, i) => {
    if (i === 0) return slope[0];
    if (i === n - 1) return slope[n - 2];
    // A turning point gets a flat tangent; otherwise use the harmonic mean to stay monotone.
    return slope[i - 1] * slope[i] <= 0 ? 0 : (2 * slope[i - 1] * slope[i]) / (slope[i - 1] + slope[i]);
  });
  let d = `M${points[0].x},${points[0].y}`;
  for (let i = 0; i < n - 1; i++) {
    const h = dx[i] / 3;
    d += ` C${points[i].x + h},${points[i].y + tangent[i] * h} ${points[i + 1].x - h},${points[i + 1].y - tangent[i + 1] * h} ${points[i + 1].x},${points[i + 1].y}`;
  }
  return d;
}

/** The same curve closed down to `baseline`, for the gradient area under a line. */
export function areaPath(points: readonly Point[], baseline: number): string {
  if (points.length < 2) return "";
  const first = points[0];
  const last = points[points.length - 1];
  return `${smoothPath(points)} L${last.x},${baseline} L${first.x},${baseline} Z`;
}

/** First day of each month strictly inside (day0, day1], as whole epoch days with a "Jul" label. */
export function monthTicks(day0: number, day1: number): { day: number; label: string }[] {
  const ticks: { day: number; label: string }[] = [];
  const start = new Date(day0 * DAY_MS);
  let y = start.getUTCFullYear();
  let m = start.getUTCMonth() + 1;
  for (;;) {
    if (m > 11) {
      m = 0;
      y += 1;
    }
    const day = Math.round(Date.UTC(y, m, 1) / DAY_MS);
    if (day > day1) return ticks;
    ticks.push({ day, label: MONTHS[m] });
    m += 1;
  }
}
