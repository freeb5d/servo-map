// Writes the platform outputs from src/tokens.ts. The drift test fails when these are stale.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { emitCss } from "../src/emit-css";
import { emitSwift } from "../src/emit-swift";

const out = (path: string) => fileURLToPath(new URL(`../generated/${path}`, import.meta.url));

writeFileSync(out("tokens.css"), emitCss());
writeFileSync(out("swift/ServoMapTokens.swift"), emitSwift());
console.log("design-tokens: wrote generated/tokens.css and generated/swift/ServoMapTokens.swift");
