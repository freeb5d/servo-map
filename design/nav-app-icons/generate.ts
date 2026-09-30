/**
 * The icons of the navigation apps Settings › Directions offers (decision 0008), and their copy in
 * the iOS asset catalog. Each `{id}.jpg` here is the only copy anyone edits; ids match `NavApp` in
 * apps/ios/Sources/DirectionsLauncher.swift.
 *
 * Run from the repository root:
 *   pnpm nav-app-icons fetch     download the current App Store artwork (artworkUrl512) into this folder
 *   pnpm nav-app-icons           copy the icons into the iOS asset catalog
 *   pnpm nav-app-icons --check   exit 1 when the asset catalog copy is stale (CI)
 */
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");
const IOS_DIR = join(ROOT, "apps/ios/Resources/Assets.xcassets/NavAppIcons");
const XCODE_INFO = { author: "xcode", version: 1 };

/** App Store ids, as the lookup API takes them. */
const APPS = { apple: 915056765, google: 585027354, waze: 323229106 } as const;
type AppId = keyof typeof APPS;
const IDS = Object.keys(APPS) as AppId[];

const json = (value: unknown) => `${JSON.stringify(value, null, 2)}\n`;

interface Output {
  path: string;
  contents: Buffer | string;
}

function outputs(): Output[] {
  const files: Output[] = [
    { path: join(IOS_DIR, "Contents.json"), contents: json({ info: XCODE_INFO, properties: { "provides-namespace": false } }) },
  ];
  for (const id of IDS) {
    const imageset = join(IOS_DIR, `nav-${id}.imageset`);
    files.push(
      { path: join(imageset, `nav-${id}.jpg`), contents: readFileSync(join(HERE, `${id}.jpg`)) },
      { path: join(imageset, "Contents.json"), contents: json({ images: [{ filename: `nav-${id}.jpg`, idiom: "universal" }], info: XCODE_INFO }) },
    );
  }
  return files;
}

/** Image sets left behind by an app no longer listed. */
function strays(): string[] {
  if (!existsSync(IOS_DIR)) return [];
  const keep = new Set(IDS.map((id) => `nav-${id}.imageset`));
  return readdirSync(IOS_DIR)
    .filter((entry) => entry.endsWith(".imageset") && !keep.has(entry))
    .map((entry) => join(IOS_DIR, entry));
}

function isCurrent(output: Output): boolean {
  if (!existsSync(output.path)) return false;
  const want = typeof output.contents === "string" ? Buffer.from(output.contents) : output.contents;
  return readFileSync(output.path).equals(want);
}

async function fetchIcons(): Promise<void> {
  const url = `https://itunes.apple.com/lookup?id=${IDS.map((id) => APPS[id]).join(",")}&country=au`;
  const lookup = (await (await fetch(url)).json()) as { results: { trackId: number; artworkUrl512?: string }[] };
  for (const id of IDS) {
    const artwork = lookup.results.find((r) => r.trackId === APPS[id])?.artworkUrl512;
    if (!artwork) throw new Error(`No artworkUrl512 for ${id} (${APPS[id]})`);
    const image = Buffer.from(await (await fetch(artwork)).arrayBuffer());
    writeFileSync(join(HERE, `${id}.jpg`), image);
    console.log(`nav-app-icons: ${id}.jpg from ${artwork}`);
  }
}

function copy(check: boolean): void {
  const stale = outputs().filter((output) => !isCurrent(output));
  const extra = strays();
  const show = (path: string) => relative(ROOT, path);
  if (check) {
    if (stale.length === 0 && extra.length === 0) {
      console.log(`nav-app-icons: ${IDS.length} icons in sync`);
      return;
    }
    for (const output of stale) console.error(`stale: ${show(output.path)}`);
    for (const path of extra) console.error(`not generated from design/nav-app-icons: ${show(path)}`);
    console.error("Run `pnpm nav-app-icons` and commit the result.");
    process.exit(1);
  }
  for (const output of stale) {
    mkdirSync(dirname(output.path), { recursive: true });
    writeFileSync(output.path, output.contents);
  }
  for (const path of extra) rmSync(path, { recursive: true });
  console.log(`nav-app-icons: ${IDS.length} icons; wrote ${stale.length} files, removed ${extra.length}`);
}

async function main(): Promise<void> {
  if (process.argv.includes("fetch")) {
    await fetchIcons();
    copy(false);
  } else {
    copy(process.argv.includes("--check"));
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
