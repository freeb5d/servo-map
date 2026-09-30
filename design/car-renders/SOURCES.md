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
  material. The apps label them as illustrations.
- **Where they go:** `pnpm car-renders` copies them to `packages/web/public/cars/`, and apps load them
  from `/cars/{id}.jpg` on the site. `pnpm car-renders --check` fails CI when a copy is stale or an
  image has no manifest entry.

To replace one image, rerun with `--only={id} --force`, check it, and commit the image with its
manifest entry.

Badges: per-model renders keep the maker's badge, as on the real car (owner's decision,
2026-09-30); the badge identifies the vehicle and implies no endorsement. Door decals and model
lettering are prompted away and checked in review. The generic stand-ins carry no badge or lettering.

Review of the first catalogue run (2026-09-30): every render was checked on labelled contact
sheets (256 × 144). 16 were dropped and fall back to their body type's stand-in: 15 generations from
2021 on that the model drew as the previous generation (Everest, Ranger, Civic, CR-V, Kona, Santa Fe,
Carnival, MG ZS, Outlander, Triton, X-Trail, Swift, LandCruiser 300, Prado) or with another maker's
grille (Tank 300), and one with lettering on the plate (Crosstrek). Four grey studio backgrounds were
flood-filled to white. Ten Volkswagen generations were not rendered because the fal balance ran out;
rerun `generate --only=…` for them after a top-up.
