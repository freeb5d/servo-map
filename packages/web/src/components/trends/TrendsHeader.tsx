import type { AustralianState } from "@servo-map/shared";
import { NEAR_RADIUS_KM } from "./useNearYou";
import { RANGES, type Range } from "./useTrendsParams";

interface TrendsHeaderProps {
  eyebrow: string;
  headline: string;
  states: { state: AustralianState; label: string }[];
  state: AustralianState;
  onState: (state: AustralianState) => void;
  range: Range;
  onRange: (range: Range) => void;
  placeLabel: string;
  onLocate: () => void;
  locating: boolean;
  locationError: string | null;
}

/** Page head: the verdict as a headline, the state and range switches, and where "near you" is. */
export function TrendsHeader(props: TrendsHeaderProps) {
  const { states, state, onState, range, onRange } = props;
  return (
    <header className="grid gap-3">
      <div className="flex flex-wrap items-end justify-between gap-x-4 gap-y-3">
        <div className="grid min-w-0 flex-1 basis-[22rem] gap-1">
          <span className="caption">{props.eyebrow}</span>
          <h1 className="font-display text-[21px] font-medium leading-[1.3] text-balance md:text-display">
            {props.headline}
          </h1>
        </div>
        <div className="flex flex-wrap items-center gap-2 md:grid md:justify-items-end md:gap-1.5">
          {states.length > 1 && (
            <div role="group" aria-label="State" className="seg">
              {states.map((s) => (
                <button key={s.state} type="button" aria-pressed={state === s.state} className="seg-item" onClick={() => onState(s.state)}>
                  {s.label}
                </button>
              ))}
            </div>
          )}
          <div role="group" aria-label="Range" className="seg">
            {RANGES.map((r) => (
              <button key={r} type="button" aria-pressed={range === r} className="seg-item" onClick={() => onRange(r)}>
                {r} d
              </button>
            ))}
          </div>
        </div>
      </div>
      <p className="flex flex-wrap items-center gap-x-2 text-small text-ink-3">
        <span>
          Near you means within {NEAR_RADIUS_KM} km of {props.placeLabel}.
        </span>
        <button type="button" className="btn btn-quiet btn-sm" onClick={props.onLocate} disabled={props.locating}>
          {props.locating ? "Finding you…" : "Use my location"}
        </button>
        {props.locationError && <span role="alert">Location unavailable: {props.locationError}.</span>}
      </p>
    </header>
  );
}
