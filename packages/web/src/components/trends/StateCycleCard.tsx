import type { FuelType, PriceSnapshot } from "@servo-map/shared";
import { cyclePosition, cycleVerdict, windowSpanDays } from "@/lib/trends";
import { Card } from "./Card";
import { RangeLine } from "@/components/ui/RangeLine";

interface StateCycleCardProps {
  series: PriceSnapshot[];
  fuel: FuelType;
  stateLabel: string;
}

/** Where the state's price cycle stands, for the SEO pages' side column. Empty history renders nothing. */
export function StateCycleCard({ series, fuel, stateLabel }: StateCycleCardProps) {
  const cycle = cyclePosition(series, fuel);
  if (!cycle) return null;
  const verdict = cycleVerdict(cycle.position, cycle.current === cycle.max, windowSpanDays(series, fuel));

  return (
    <Card label={`${stateLabel} cycle`}>
      <RangeLine min={cycle.min} max={cycle.max} current={cycle.current} days={windowSpanDays(series, fuel)} />
      <p className="text-body text-ink-2">{verdict}</p>
    </Card>
  );
}
