import { DATA_SOURCES, dataAttribution, type AustralianState } from "@servo-map/shared";
import { cn } from "@/lib/utils";

/**
 * What a state's data licence makes us show next to its prices (decision 0007): the prescribed
 * statement (QLD, SA, VIC) and, for SA, where to report a stale price. Renders nothing for states
 * whose licence asks only for credit, which the "via …" line already gives.
 */
export function SourceNotice({ state, className }: { state: AustralianState; className?: string }) {
  const statement = dataAttribution(state, new Date().getFullYear());
  const reportUrl = DATA_SOURCES[state].reportUrl;
  if (!statement && !reportUrl) return null;
  return (
    <p className={cn("text-ink-3", className)}>
      {statement}
      {reportUrl && (
        <>
          {statement ? " " : ""}
          Price out of date?{" "}
          <a href={reportUrl} target="_blank" rel="noopener noreferrer" className="link">
            Report it to Consumer and Business Services
          </a>
          .
        </>
      )}
    </p>
  );
}
