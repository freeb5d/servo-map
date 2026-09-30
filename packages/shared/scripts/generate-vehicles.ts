// Writes src/generated/vehicles.data.ts from data/vehicles.csv; the drift test fails when it is stale.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { emitVehiclesModule } from "../src/emit-vehicles";

const csv = readFileSync(fileURLToPath(new URL("../data/vehicles.csv", import.meta.url)), "utf8");
mkdirSync(fileURLToPath(new URL("../src/generated", import.meta.url)), { recursive: true });
writeFileSync(fileURLToPath(new URL("../src/generated/vehicles.data.ts", import.meta.url)), emitVehiclesModule(csv));
console.log("shared: wrote src/generated/vehicles.data.ts");
