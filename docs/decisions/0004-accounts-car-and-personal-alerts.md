# 0004 — Accounts, the car catalogue and personal alerts

- Date: 2026-09-30
- Status: **accepted**
- Owner: Henry Chen
- Evidence: [`docs/design/you-and-sync.html`](../design/you-and-sync.html) (navigation, car page and alert sketches)

## Problem

Saved stations and the fill-up log live on one iPhone and take two of five tabs. The owner wants
them behind a per-user avatar, synced, with sign-in by Apple or Google; a car chosen from shared
catalogue data with a side view and an automatic (overridable) tank size; and notifications that
speak to the user's own stations, car and habits.

## Options

Navigation: tabs Nearby · Trends · Search, and an avatar opening "You" (Saved · Log · Car · Alerts).

Sync:
- A. CloudKit private database. No Google sign-in (CloudKit data is tied to iCloud); no web sync;
  server alerts need prices copied into CloudKit.
- B. ServoMap accounts: the Worker verifies Apple and Google identity tokens and stores user data in
  Cloudflare D1 behind `/api/v1/me/*`. Syncs iOS and web; the alert job knows each user's stations.
- C. CloudKit for data plus a sign-in used only for server alerts. Two stores to keep in step.

Car data: curated tank sizes for about 150 models from manufacturer spec sheets (with sources), or a
licensed dataset. Pictures: body-shape drawings tinted by colour; no manufacturer photos (copyright).

Alerts: price drop at a saved station and cycle low near home (server); fill-up due and monthly
summary (device). At most one a day, quiet hours, a switch per kind.

## Choice

Chosen by the owner on 2026-09-30:

- **Sync: option B.** ServoMap accounts with Sign in with Apple and Google, user data in Cloudflare
  D1 behind `/api/v1/me/*`, shared by iOS and web. Sign-in stays optional; local data merges into the
  account on first sign-in; accounts can be deleted in the app.
- **Car data:** tank sizes curated from manufacturer spec sheets for about 150 best-selling models,
  each with its source; other cars entered by hand. Served at `/api/v1/vehicles`.
- **Car picture:** body-shape drawings tinted by the chosen colour.
- **First alerts:** price drop at a saved station, and cycle low near home. Both are sent by the
  server after ingest through APNs.

Build order: the You sheet (local), the car catalogue, accounts and sync, then alerts.
