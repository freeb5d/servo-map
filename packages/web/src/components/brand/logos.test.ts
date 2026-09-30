import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { BRAND_FAMILIES } from "@servo-map/shared";
import { BRAND_LOGO_IDS, brandLogoSrc } from "./logos";

const publicFile = (src: string) => fileURLToPath(new URL(`../../../public${src}`, import.meta.url));

describe("brand logos", () => {
  it("names only real brand families", () => {
    const ids = new Set(BRAND_FAMILIES.map((family) => family.id));
    expect([...BRAND_LOGO_IDS].filter((id) => !ids.has(id))).toEqual([]);
  });

  it("serves a file for every logo id", () => {
    for (const id of BRAND_LOGO_IDS) {
      const src = brandLogoSrc(id);
      expect(src).toBe(`/brand-logos/${id}.png`);
      expect(existsSync(publicFile(src as string)), src as string).toBe(true);
    }
  });

  it("has no logo for brands that draw the monogram tile (decision 0003)", () => {
    for (const id of ["speedway", "astron", "u-go", "costco", "independent"]) {
      expect(brandLogoSrc(id)).toBeNull();
    }
  });
});
