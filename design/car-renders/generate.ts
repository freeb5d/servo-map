/**
 * One studio render per catalogue generation (decision 0008), and the copies the apps serve.
 *
 * Each `{vehicle id}.jpg` in this folder is the only copy anyone edits; `manifest.json` records how
 * it was made (model, prompt, seed, date) and whether a person has checked it.
 *
 * Run from the repository root:
 *   op run --env-file=design/car-renders/.env.op -- pnpm car-renders generate [--only id,id] [--force]
 *                                  render missing images through fal (needs FAL_KEY and ImageMagick)
 *   ... pnpm car-renders generate --generic   render the one-per-body-type stand-ins
 *   pnpm car-renders               copy the images to packages/web/public/cars
 *   pnpm car-renders --check       exit 1 when a copy is stale or an image has no manifest entry (CI)
 */
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { VEHICLES } from "../../packages/shared/src/generated/vehicles.data";
import type { Vehicle } from "../../packages/shared/src/vehicles";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");
const WEB_DIR = join(ROOT, "packages/web/public/cars");
const MANIFEST = join(HERE, "manifest.json");
const SHARED_TS = join(ROOT, "packages/shared/src/generated/car-renders.ts");
const MODEL = "fal-ai/flux-2-max";
const SIZE = { width: 1024, height: 640 };

/** How each image was made; `reviewed` is set by hand once a person has checked the render. */
interface Entry {
  prompt: string;
  model: string;
  seed: number | null;
  generatedAt: string;
  reviewed: boolean;
}
type Manifest = Record<string, Entry>;

const BODY_WORDS: Record<Vehicle["body"], string> = {
  hatch: "hatchback",
  sedan: "sedan",
  wagon: "station wagon",
  suv: "SUV",
  ute: "ute",
  van: "van",
};

/** Stand-in images, one per body type, for generations that have no render of their own. */
export const GENERIC_IDS = Object.keys(BODY_WORDS).map((body) => `generic-${body}`);

/** An unbranded, fictional car of one body type: no maker's design, so no trademark in the picture. */
export function genericPromptFor(body: Vehicle["body"]): string {
  return [
    `Studio catalogue render of a white modern generic ${BODY_WORDS[body]} of no real brand, an original unbranded design`,
    "front three-quarter view, vehicle facing left (front of the vehicle on the left side of the image)",
    "seen from slightly above eye level, full vehicle in frame, pure white seamless background",
    "soft grey contact shadow under the tyres, crisp realistic reflections, simple five-spoke wheels",
    "blank number plates, no badges, no emblems, no logos, no lettering anywhere on the vehicle, no watermark, no people",
  ].join(", ");
}

/** The prompt for one generation. The maker's badge stays, as on the real car (decision 0008). */
export function promptFor(v: Vehicle): string {
  const until = v.toYear ?? "today";
  const year = v.toYear ? Math.round((v.fromYear + v.toYear) / 2) : v.fromYear + 2;
  return [
    `Studio catalogue render of a white ${year} ${v.make} ${v.model} ${BODY_WORDS[v.body]}`,
    `(the generation sold in Australia from ${v.fromYear} to ${until})`,
    "front three-quarter view, vehicle facing left (front of the vehicle on the left side of the image)",
    "seen from slightly above eye level, full vehicle in frame, pure white seamless background",
    "soft grey contact shadow under the tyres, crisp realistic reflections, factory wheels",
    "blank number plates, no lettering or model names on the doors, no text, no watermark, no people",
  ].join(", ");
}

function readManifest(): Manifest {
  return existsSync(MANIFEST) ? (JSON.parse(readFileSync(MANIFEST, "utf8")) as Manifest) : {};
}

function writeManifest(manifest: Manifest): void {
  const sorted = Object.fromEntries(Object.entries(manifest).sort(([a], [b]) => a.localeCompare(b)));
  writeFileSync(MANIFEST, `${JSON.stringify(sorted, null, 2)}\n`);
}

async function falJson(url: string, key: string, body?: unknown): Promise<Record<string, unknown>> {
  const res = await fetch(url, {
    method: body ? "POST" : "GET",
    headers: { Authorization: `Key ${key}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`fal ${res.status} for ${url}: ${(await res.text()).slice(0, 300)}`);
  return (await res.json()) as Record<string, unknown>;
}

/** Queues one render and waits for it; returns the image bytes and the seed. */
async function render(prompt: string, key: string): Promise<{ bytes: Buffer; seed: number | null }> {
  const queued = await falJson(`https://queue.fal.run/${MODEL}`, key, {
    prompt,
    image_size: SIZE,
    num_images: 1,
    output_format: "png",
  });
  const statusUrl = String(queued.status_url);
  const responseUrl = String(queued.response_url);
  for (let attempt = 0; attempt < 90; attempt += 1) {
    const status = await falJson(statusUrl, key);
    if (status.status === "COMPLETED") break;
    if (attempt === 89) throw new Error(`fal render timed out: ${responseUrl}`);
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  const result = await falJson(responseUrl, key);
  const image = (result.images as { url: string }[] | undefined)?.[0];
  if (!image) throw new Error(`fal returned no image: ${responseUrl}`);
  const res = await fetch(image.url);
  if (!res.ok) throw new Error(`download ${res.status}: ${image.url}`);
  return { bytes: Buffer.from(await res.arrayBuffer()), seed: typeof result.seed === "number" ? result.seed : null };
}

/**
 * Trims the render, centres it on a 640 x 360 white canvas and pushes the near-white studio
 * background to pure white, so it disappears when drawn with multiply on the paper colour.
 */
function finish(png: Buffer, out: string): void {
  const tmp = `${out}.png`;
  writeFileSync(tmp, png);
  try {
    execFileSync("magick", [
      tmp, "-fuzz", "4%", "-trim", "+repage", "-resize", "592x",
      "-background", "white", "-gravity", "center", "-extent", "640x360",
      "-channel", "RGB", "-level", "0%,93%", "+channel", "-quality", "86", out,
    ]);
  } finally {
    rmSync(tmp, { force: true });
  }
}

async function generate(args: string[]): Promise<void> {
  const key = process.env.FAL_KEY;
  if (!key) throw new Error("FAL_KEY is not set; run through `op run --env-file=design/car-renders/.env.op --`");
  const onlyArg = args.find((a) => a.startsWith("--only="));
  const only = onlyArg ? new Set(onlyArg.slice("--only=".length).split(",")) : null;
  const force = args.includes("--force");
  const manifest = readManifest();
  const generic = args.includes("--generic");
  const jobs = generic
    ? (Object.keys(BODY_WORDS) as Vehicle["body"][]).map((body) => ({ id: `generic-${body}`, prompt: genericPromptFor(body) }))
    : VEHICLES.map((v) => ({ id: v.id, prompt: promptFor(v) }));
  const todo = jobs.filter((j) => (!only || only.has(j.id)) && (force || !existsSync(join(HERE, `${j.id}.jpg`))));
  console.log(`car-renders: ${todo.length} to render with ${MODEL}`);
  const queue = [...todo];
  const failed: string[] = [];
  // Four renders at a time keeps a full catalogue run to minutes without hammering the queue.
  const worker = async () => {
    for (let v = queue.shift(); v; v = queue.shift()) {
      const { prompt } = v;
      try {
        const { bytes, seed } = await render(prompt, key);
        finish(bytes, join(HERE, `${v.id}.jpg`));
        manifest[v.id] = { prompt, model: MODEL, seed, generatedAt: new Date().toISOString(), reviewed: false };
        writeManifest(manifest);
        console.log(`  ${v.id}`);
      } catch (error) {
        // One failed render must not lose the others; report it and carry on.
        failed.push(v.id);
        console.error(`  ${v.id} failed: ${(error as Error).message}`);
      }
    }
  };
  await Promise.all([worker(), worker(), worker(), worker()]);
  if (failed.length > 0) {
    console.error(`car-renders: ${failed.length} failed; rerun with --only=${failed.join(",")}`);
    process.exitCode = 1;
  }
}

/** The web copies the apps load from `/cars/{id}.jpg`. */
function outputs(): { path: string; contents: Buffer }[] {
  return readdirSync(HERE)
    .filter((f) => f.endsWith(".jpg"))
    .sort()
    .map((f) => ({ path: join(WEB_DIR, f), contents: readFileSync(join(HERE, f)) }));
}

/** The ids of generations with a render of their own; the rest use their body type's stand-in. */
function sharedModule(): string {
  const ids = readdirSync(HERE)
    .filter((f) => f.endsWith(".jpg") && !f.startsWith("generic-"))
    .map((f) => f.slice(0, -".jpg".length))
    .sort();
  return [
    "// Generated by design/car-renders/generate.ts from the renders in design/car-renders. Do not edit.",
    "",
    "/** Catalogue generations with a render of their own at `/cars/{id}.jpg`. */",
    `export const RENDERED_VEHICLE_IDS: ReadonlySet<string> = new Set(${JSON.stringify(ids)});`,
    "",
  ].join("\n");
}

function copyOrCheck(check: boolean): void {
  const manifest = readManifest();
  const ids = new Set([...VEHICLES.map((v) => v.id), ...GENERIC_IDS]);
  const problems: string[] = [];
  for (const f of readdirSync(HERE).filter((name) => name.endsWith(".jpg"))) {
    const id = f.slice(0, -".jpg".length);
    if (!ids.has(id)) problems.push(`${f} names no catalogue vehicle`);
    if (!manifest[id]) problems.push(`${f} has no manifest entry`);
  }
  const wanted = outputs();
  const wantedNames = new Set(wanted.map((o) => o.path));
  const stale = existsSync(WEB_DIR)
    ? readdirSync(WEB_DIR).map((f) => join(WEB_DIR, f)).filter((p) => !wantedNames.has(p))
    : [];
  if (check) {
    for (const o of wanted) {
      if (!existsSync(o.path) || !readFileSync(o.path).equals(o.contents)) problems.push(`stale copy: ${o.path}`);
    }
    for (const p of stale) problems.push(`orphan copy: ${p}`);
    if (!existsSync(SHARED_TS) || readFileSync(SHARED_TS, "utf8") !== sharedModule()) problems.push(`stale: ${SHARED_TS}`);
    if (problems.length > 0) {
      console.error(`car-renders --check failed; run \`pnpm car-renders\`:\n  ${problems.join("\n  ")}`);
      process.exit(1);
    }
    console.log(`car-renders: ${wanted.length} images, copies current`);
    return;
  }
  if (problems.length > 0) {
    console.error(`car-renders:\n  ${problems.join("\n  ")}`);
    process.exit(1);
  }
  mkdirSync(WEB_DIR, { recursive: true });
  for (const p of stale) rmSync(p);
  for (const o of wanted) writeFileSync(o.path, o.contents);
  writeFileSync(SHARED_TS, sharedModule());
  console.log(`car-renders: copied ${wanted.length} images to ${WEB_DIR} and wrote ${SHARED_TS}`);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args[0] === "generate") await generate(args.slice(1));
  else copyOrCheck(args.includes("--check"));
}

main().catch((error: unknown) => {
  console.error((error as Error).message);
  process.exit(1);
});
