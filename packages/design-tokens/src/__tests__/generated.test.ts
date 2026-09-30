import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { emitCss } from "../emit-css";
import { emitJson } from "../emit-json";
import { emitSwift } from "../emit-swift";

const committed = (path: string) =>
  readFileSync(fileURLToPath(new URL(`../../generated/${path}`, import.meta.url)), "utf8");

// The committed outputs are copies of tokens.ts; this is the check that fails when they drift.
describe("generated outputs", () => {
  it("tokens.css matches src/tokens.ts (run `pnpm --filter @servo-map/design-tokens generate`)", () => {
    expect(committed("tokens.css")).toBe(emitCss());
  });

  it("tokens.json matches src/tokens.ts", () => {
    expect(committed("tokens.json")).toBe(emitJson());
  });

  it("ServoMapTokens.swift matches src/tokens.ts", () => {
    expect(committed("swift/ServoMapTokens.swift")).toBe(emitSwift());
  });

  it("emits the dark override for every colour token", () => {
    const css = emitCss();
    const dark = css.slice(css.indexOf(':root[data-theme="dark"]'));
    expect(dark).toContain("--color-price-cheap: #93B597;");
    expect(dark).toContain("--color-accent: #E6E3DB;");
  });
});
