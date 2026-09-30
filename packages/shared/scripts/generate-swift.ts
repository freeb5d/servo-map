// Writes the generated Swift files iOS compiles; the drift tests fail when one is stale.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { emitBrandsSwift } from "../src/emit-brands-swift";
import { emitDataSourcesSwift } from "../src/emit-data-sources-swift";
import { emitVehicleImagesSwift } from "../src/emit-vehicle-images-swift";

const outputs: [string, string][] = [
  ["ServoMapBrands.swift", emitBrandsSwift()],
  ["ServoMapDataSources.swift", emitDataSourcesSwift()],
  ["ServoMapVehicleImages.swift", emitVehicleImagesSwift()],
];
for (const [file, source] of outputs) {
  writeFileSync(fileURLToPath(new URL(`../generated/swift/${file}`, import.meta.url)), source);
  console.log(`shared: wrote generated/swift/${file}`);
}
