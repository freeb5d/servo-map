// Writes generated/swift/ServoMapBrands.swift; the drift test fails when it is stale.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { emitBrandsSwift } from "../src/emit-brands-swift";

writeFileSync(fileURLToPath(new URL("../generated/swift/ServoMapBrands.swift", import.meta.url)), emitBrandsSwift());
console.log("shared: wrote generated/swift/ServoMapBrands.swift");
