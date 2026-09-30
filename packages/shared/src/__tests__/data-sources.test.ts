import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { AUSTRALIAN_STATES } from "../states";
import { DATA_SOURCES, dataAttribution } from "../data-sources";
import { emitDataSourcesSwift } from "../emit-data-sources-swift";

describe("DATA_SOURCES", () => {
  it("credits every state with an https source", () => {
    for (const state of AUSTRALIAN_STATES) {
      expect(DATA_SOURCES[state].name).not.toBe("");
      expect(DATA_SOURCES[state].url).toMatch(/^https:\/\//);
    }
  });

  it("dates Queensland's statement and keeps its no-warranty terms", () => {
    const qld = dataAttribution("qld", 2026)!;
    expect(qld).toMatch(/^Based on or contains data provided by the State of Queensland \(Department of Energy and Climate\) 2026\. /);
    expect(qld).toContain("gives no warranty in relation to the data");
    expect(qld).not.toContain("{year}");
  });

  it("gives South Australia its statement and a place to report stale prices", () => {
    expect(dataAttribution("sa", 2026)).toMatch(/^Based on or contains data provided by the State of South Australia/);
    expect(DATA_SOURCES.sa.reportUrl).toBe("https://www.cbs.sa.gov.au/fuel");
  });

  it("uses Victoria's prescribed notice as written", () => {
    expect(dataAttribution("vic", 2026)).toBe(
      "© State of Victoria accessed via the Victorian Government Service Victoria Platform",
    );
  });

  it("has no statement where the licence asks only for credit", () => {
    for (const state of ["nsw", "act", "tas", "wa"] as const) expect(dataAttribution(state, 2026)).toBeNull();
  });
});

describe("emitDataSourcesSwift", () => {
  it("matches the committed Swift file (run `pnpm --filter @servo-map/shared generate`)", () => {
    const committed = readFileSync(
      fileURLToPath(new URL("../../generated/swift/ServoMapDataSources.swift", import.meta.url)),
      "utf8",
    );
    expect(committed).toBe(emitDataSourcesSwift());
  });

  it("emits every state", () => {
    const swift = emitDataSourcesSwift();
    for (const state of AUSTRALIAN_STATES) expect(swift).toContain(`"${state}": DataSource(`);
  });
});
