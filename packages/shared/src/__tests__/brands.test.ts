import { describe, expect, it } from "vitest";
import { BRAND_FAMILIES, brandFamily, brandFamilyById } from "../brands";

describe("brandFamily", () => {
  it.each([
    ["Ampol", "ampol"],
    ["Ampol Foodary", "ampol"],
    ["EG Ampol", "ampol"],
    ["Ampol Breeze", "ampol"],
    ["Reddy Express", "shell"],
    ["Shell", "shell"],
    ["Metro Fuel", "metro"],
    ["OMG Metro", "metro"],
    ["ASTRON", "astron"],
    ["Astron", "astron"],
    ["UGO", "u-go"],
    ["U-Go", "u-go"],
    ["Mobil 1 Carlingford Car Care", "mobil"],
    ["7-Eleven", "7-eleven"],
    ["Costco", "costco"],
    ["  bp  ", "bp"],
  ])("maps %s to %s", (raw, id) => {
    expect(brandFamily(raw).id).toBe(id);
  });

  it("falls back to Independent for unknown and empty names", () => {
    expect(brandFamily("Bribbaree Servo").id).toBe("independent");
    expect(brandFamily("Pearl Energy").id).toBe("independent");
    expect(brandFamily("").id).toBe("independent");
  });

  it("does not let a short exact name match by substring", () => {
    // "bp" is exact-only, so a name merely containing the letters stays independent.
    expect(brandFamily("BP Lite Plus Store").id).toBe("independent");
  });
});

describe("BRAND_FAMILIES", () => {
  it("has unique ids and seals of at most three characters", () => {
    const ids = BRAND_FAMILIES.map((f) => f.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const f of BRAND_FAMILIES) expect(f.seal.length).toBeLessThanOrEqual(3);
  });

  it("finds families by id", () => {
    expect(brandFamilyById("metro")?.name).toBe("Metro");
    expect(brandFamilyById("nope")).toBeUndefined();
  });
});

/** WCAG 2.x contrast; kept here so shared stays free of other workspace packages. */
function contrast(a: string, b: string): number {
  const lum = (hex: string) => {
    const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
      .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

describe("brand marks", () => {
  it.each(BRAND_FAMILIES.map((f) => [f.id, f.mark] as const))("%s monogram reaches WCAG AA", (_id, mark) => {
    expect(contrast(mark.foreground, mark.background)).toBeGreaterThanOrEqual(4.5);
  });

  it("uses #RRGGBB colours only", () => {
    for (const { mark } of BRAND_FAMILIES) {
      for (const c of [mark.background, mark.foreground, mark.stripe].filter(Boolean)) {
        expect(c).toMatch(/^#[0-9A-F]{6}$/);
      }
    }
  });
});
