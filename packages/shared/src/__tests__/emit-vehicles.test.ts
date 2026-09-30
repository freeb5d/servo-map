import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { emitVehiclesModule } from "../emit-vehicles";
import { VEHICLES } from "../generated/vehicles.data";

const csv = readFileSync(fileURLToPath(new URL("../../data/vehicles.csv", import.meta.url)), "utf8");

describe("emitVehiclesModule", () => {
  it("matches the committed module (run `pnpm --filter @servo-map/shared generate`)", () => {
    const committed = readFileSync(
      fileURLToPath(new URL("../generated/vehicles.data.ts", import.meta.url)),
      "utf8",
    );
    expect(committed).toBe(emitVehiclesModule(csv));
  });

  it("ships a catalogue with unique ids and a source for every row", () => {
    expect(VEHICLES.length).toBeGreaterThanOrEqual(150);
    expect(new Set(VEHICLES.map((v) => v.id)).size).toBe(VEHICLES.length);
    for (const v of VEHICLES) expect(v.source).toMatch(/^https:\/\//);
  });
});
