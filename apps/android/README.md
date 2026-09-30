# ServoMap for Android

Kotlin and Jetpack Compose client for the public ServoMap API. It runs on phones, tablets,
foldables, Chromebooks and Android TV (minSdk 21), and uses the same design tokens, brand logos and
Shippori Mincho typeface as the iPhone app.

## Build

CI builds it (`.github/workflows/android.yml`) and uploads the debug APK. Locally, with JDK 17 and
Gradle 8.11:

```bash
cd apps/android
gradle testDebugUnitTest assembleDebug
```

Gradle properties (`-P` or `~/.gradle/gradle.properties`):

| Property | Effect |
|---|---|
| `apiBase` | API root. Defaults to `https://api.servo-map.com/api/v1`; `http://10.0.2.2:8787/api/v1` reaches a local `wrangler dev` from the emulator. |
| `googleClientId` | Google OAuth **web** client id. Empty (the default) hides the Google sign-in button. |

## Features

Nearby map and list, fuel and brand filters, search, trends (states, cities, best weekday), station
detail, saved stations, fill-up log with CSV export, car, settings (appearance, directions app,
compare radius), data-source credits, optional account sync, price alerts and a
"Cheapest nearby" home-screen widget.

## Accounts and alerts: what the server has to provide

**Sign-in and sync** call `/api/v1/auth/google` and `/api/v1/me/*`, exactly as the iPhone app does.
Until the worker has `GOOGLE_CLIENT_IDS` set (`docs/claude/security.md`) it answers 503 and the app
says accounts are not switched on; everything still works on the device. To enable it, create a
Google OAuth web client, add its id to the worker's `GOOGLE_CLIENT_IDS`, and build with the same id
as `googleClientId`. Credential Manager also needs an Android OAuth client for the app's package
name and signing key in the same Google Cloud project.

**Alerts** run on the phone. The server's alert job (`scripts/send-alerts.ts`) delivers through APNs
only, so it cannot reach Android. `AlertRules` is a port of `packages/worker/src/alerts/rules.ts`
and a background job checks every few hours, so an alert can arrive a little after a price changes.
Switches and quiet hours still sync with the account. Push to Android would need a server-side FCM
sender and a device-token route; that is a worker change, not an app change.
