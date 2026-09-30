import { describe, expect, it } from "vitest";
import { contrastRatio } from "../contrast";
import { color, markColor, type ColorToken } from "../tokens";

const TEXT: ColorToken[] = ["ink", "ink2", "ink3", "priceCheap", "priceMid", "priceExpensive"];
const GROUNDS: ColorToken[] = ["bg", "surface"];

describe("contrastRatio", () => {
  it("returns 21 for black on white and 1 for identical colours", () => {
    expect(contrastRatio("#000000", "#FFFFFF")).toBeCloseTo(21, 5);
    expect(contrastRatio("#777777", "#777777")).toBe(1);
  });
});

describe.each(["light", "dark"] as const)("%s theme meets WCAG AA", (theme) => {
  it.each(TEXT.flatMap((fg) => GROUNDS.map((bg) => [fg, bg] as const)))(
    "%s on %s is at least 4.5:1",
    (fg, bg) => {
      expect(contrastRatio(color[fg][theme], color[bg][theme])).toBeGreaterThanOrEqual(4.5);
    },
  );

  it("on-accent text on accent is at least 4.5:1", () => {
    expect(contrastRatio(color.onAccent[theme], color.accent[theme])).toBeGreaterThanOrEqual(4.5);
  });

  it("the mark's needle and ticks stand out from its tile at 3:1 (WCAG 1.4.11)", () => {
    for (const fg of [markColor.accent, markColor.ink]) {
      expect(contrastRatio(fg[theme], markColor.tile[theme])).toBeGreaterThanOrEqual(3);
    }
  });

  it("price tiers stay legible on their soft banner fills", () => {
    expect(contrastRatio(color.ink[theme], color.priceMidSoft[theme])).toBeGreaterThanOrEqual(4.5);
  });
});
