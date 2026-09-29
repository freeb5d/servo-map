import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { BRAND_FAMILIES } from "../brands";
import { emitBrandsSwift } from "../emit-brands-swift";

describe("emitBrandsSwift", () => {
  it("matches the committed Swift file (run `pnpm --filter @servo-map/shared generate`)", () => {
    const committed = readFileSync(
      fileURLToPath(new URL("../../generated/swift/ServoMapBrands.swift", import.meta.url)),
      "utf8",
    );
    expect(committed).toBe(emitBrandsSwift());
  });

  it("emits every family with Independent last", () => {
    const swift = emitBrandsSwift();
    for (const f of BRAND_FAMILIES) expect(swift).toContain(`id: "${f.id}"`);
    expect(BRAND_FAMILIES[BRAND_FAMILIES.length - 1].id).toBe("independent");
  });
});
