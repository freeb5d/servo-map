/**
 * Copies the car make marks in this folder into the iOS asset catalog (decision 0008). Each SVG
 * here is vendored from Simple Icons (see SOURCES.md), named by `makeSlug(make)` for a make in the
 * car catalogue, and is the only copy anyone edits.
 *
 * Outputs (all generated, never hand-edited):
 *   apps/ios/Resources/CarLogos.xcassets/car-{slug}.imageset   vector, template-rendered
 *
 * Run from the repository root:
 *   pnpm car-logos            write the outputs
 *   pnpm car-logos --check    exit 1 when any output is stale (CI)
 */
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { VEHICLES } from "../../packages/shared/src/generated/vehicles.data";
import { makeSlug } from "../../packages/shared/src/vehicles";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");
const IOS_DIR = join(ROOT, "apps/ios/Resources/CarLogos.xcassets");
const XCODE_INFO = { author: "xcode", version: 1 };

interface Output {
  path: string;
  contents: Buffer | string;
}

/** Mark slugs in this folder, sorted; a file that names no catalogue make is an error. */
function markSlugs(): string[] {
  const slugs = readdirSync(HERE)
    .filter((file) => file.endsWith(".svg"))
    .map((file) => file.slice(0, -".svg".length))
    .sort();
  const makes = new Set(VEHICLES.map((v) => makeSlug(v.make)));
  const unknown = slugs.filter((slug) => !makes.has(slug));
  if (unknown.length > 0) {
    throw new Error(`No catalogue make for ${unknown.join(", ")}: name each SVG by makeSlug(make).`);
  }
  return slugs;
}

const json = (value: unknown) => `${JSON.stringify(value, null, 2)}\n`;

function outputs(slugs: readonly string[]): Output[] {
  const files: Output[] = [{ path: join(IOS_DIR, "Contents.json"), contents: json({ info: XCODE_INFO }) }];
  for (const slug of slugs) {
    const imageset = join(IOS_DIR, `car-${slug}.imageset`);
    files.push(
      { path: join(imageset, `car-${slug}.svg`), contents: readFileSync(join(HERE, `${slug}.svg`)) },
      {
        path: join(imageset, "Contents.json"),
        contents: json({
          images: [{ filename: `car-${slug}.svg`, idiom: "universal" }],
          info: XCODE_INFO,
          // Drawn at any size from the vector, and tinted by the app with `brand-tile-ink`.
          properties: { "preserves-vector-representation": true, "template-rendering-intent": "template" },
        }),
      },
    );
  }
  return files;
}

/** Generated entries left behind by a mark that no longer exists here. */
function strays(slugs: readonly string[]): string[] {
  const keep = new Set(slugs);
  return existsSync(IOS_DIR)
    ? readdirSync(IOS_DIR)
        .filter((entry) => entry !== "Contents.json")
        .filter((entry) => !(entry.startsWith("car-") && entry.endsWith(".imageset") && keep.has(entry.slice("car-".length, -".imageset".length))))
        .map((entry) => join(IOS_DIR, entry))
    : [];
}

function isCurrent(output: Output): boolean {
  if (!existsSync(output.path)) return false;
  const want = typeof output.contents === "string" ? Buffer.from(output.contents) : output.contents;
  return readFileSync(output.path).equals(want);
}

function main(): void {
  const check = process.argv.includes("--check");
  const slugs = markSlugs();
  const stale = outputs(slugs).filter((output) => !isCurrent(output));
  const extra = strays(slugs);
  const show = (path: string) => relative(ROOT, path);

  if (check) {
    if (stale.length === 0 && extra.length === 0) {
      console.log(`car-logos: ${slugs.length} marks in sync`);
      return;
    }
    for (const output of stale) console.error(`stale: ${show(output.path)}`);
    for (const path of extra) console.error(`not generated from design/car-logos: ${show(path)}`);
    console.error("Run `pnpm car-logos` and commit the result.");
    process.exit(1);
  }

  for (const output of stale) {
    mkdirSync(dirname(output.path), { recursive: true });
    writeFileSync(output.path, output.contents);
  }
  for (const path of extra) rmSync(path, { recursive: true });
  console.log(`car-logos: ${slugs.length} marks; wrote ${stale.length} files, removed ${extra.length}`);
}

main();
