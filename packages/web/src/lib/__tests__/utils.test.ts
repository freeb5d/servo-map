import { describe, it, expect } from "vitest";
import { color } from "@servo-map/design-tokens";
import {
  computePriceRange,
  priceColorClass,
  priceColorHex,
  priceTier,
  tierHex,
} from "@/lib/utils";

describe("tierHex", () => {
  it.each(["light", "dark"] as const)("maps each tier to its token in the %s theme", (theme) => {
    expect(tierHex("cheap", theme)).toBe(color.priceCheap[theme]);
    expect(tierHex("fair", theme)).toBe(color.priceMid[theme]);
    expect(tierHex("pricey", theme)).toBe(color.priceExpensive[theme]);
  });

  it("gives different values per theme so contrast holds on both surfaces", () => {
    expect(tierHex("cheap", "light")).not.toBe(tierHex("cheap", "dark"));
  });
});

describe("priceColorHex", () => {
  const range = computePriceRange([180, 190, 200, 210, 220, 230]);

  it("picks the tier colour for the price in both themes", () => {
    for (const theme of ["light", "dark"] as const) {
      expect(priceColorHex(range.cheapBelow, range, theme)).toBe(color.priceCheap[theme]);
      expect(priceColorHex(range.midBelow, range, theme)).toBe(color.priceMid[theme]);
      expect(priceColorHex(range.midBelow + 1, range, theme)).toBe(color.priceExpensive[theme]);
    }
  });

  it("falls back to ink-3 without a range", () => {
    expect(priceColorHex(200, undefined, "light")).toBe(color.ink3.light);
    expect(priceColorHex(200, undefined, "dark")).toBe(color.ink3.dark);
  });

  it("defaults to the light theme", () => {
    expect(priceColorHex(200)).toBe(color.ink3.light);
  });
});

describe("priceTier / priceColorClass", () => {
  it("treats a missing range as fair", () => {
    expect(priceTier(200)).toBe("fair");
    expect(priceColorClass(200)).toBe("text-price-mid");
  });

  it("classifies by percentile thresholds", () => {
    const range = { cheapBelow: 190, midBelow: 210 };
    expect(priceTier(190, range)).toBe("cheap");
    expect(priceTier(200, range)).toBe("fair");
    expect(priceTier(211, range)).toBe("pricey");
    expect(priceColorClass(211, range)).toBe("text-price-expensive");
  });
});
