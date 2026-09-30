# Car renders

One image per body type (`generic-{body}.jpg`, unbranded fictional cars) and, over time, one per
catalogue generation (`{vehicle id}.jpg`). A generation without its own render shows its body type's
stand-in; `packages/shared/src/generated/car-renders.ts` lists the generations that have one.
Decision 0008 explains the choice.

- **How they are made:** `pnpm car-renders generate` (or `generate --generic` for the stand-ins) sends
  each prompt (`promptFor` / `genericPromptFor` in `generate.ts`) to fal.ai's `fal-ai/flux-2-max` (commercial licence for outputs). The script then trims
  each render, centres it on 640 × 360 and turns the studio background pure white, so the apps can draw
  it with multiply on the paper colour.
- **What each file records:** `manifest.json` holds the prompt, model, seed and date for every image,
  and `reviewed`. A person sets `reviewed` to `true` after checking that the render matches the
  generation (body, lights, grille, wheels) and shows no badge, text or plate number.
- **What they are not:** AI-generated illustrations, not photographs of the vehicle or manufacturer
  material. Badges are left off to keep trademarks out of the picture. The apps label them as illustrations.
- **Where they go:** `pnpm car-renders` copies them to `packages/web/public/cars/`, and apps load them
  from `/cars/{id}.jpg` on the site. `pnpm car-renders --check` fails CI when a copy is stale or an
  image has no manifest entry.

To replace one image, rerun with `--only={id} --force`, check it, and commit the image with its
manifest entry.

Known limit: the model draws the maker's badge on real models even when told not to (checked on a
CX-5 and a HiLux on 2026-09-30), so per-model renders need the badge removed, or a decision to keep
it, before they are added. The generic stand-ins were each checked for badges and lettering.
