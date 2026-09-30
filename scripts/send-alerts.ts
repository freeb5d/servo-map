/**
 * Personal alerts (decision 0004), run by GitHub Actions right after each ingest.
 *
 * Reads accounts from D1 and prices from KV through Cloudflare's REST APIs, decides what to send
 * with the rules in packages/worker/src/alerts/rules.ts, and delivers through APNs over HTTP/2
 * (which a Worker cannot open, hence this job). Exits quietly when it is not configured yet.
 *
 * Environment:
 *   CF_ACCOUNT_ID, CF_API_TOKEN, CF_KV_NAMESPACE_ID  Cloudflare (the token needs D1 and KV access)
 *   D1_DATABASE_ID                                    the servo-map accounts database
 *   APNS_KEY, APNS_KEY_ID, APNS_TEAM_ID               APNs auth key (.p8 contents) and its ids
 *   APNS_TOPIC                                        the app's bundle id
 */

import { connect } from "node:http2";
import { createSign } from "node:crypto";
import type { AustralianState, FuelType, PriceSnapshot, Station } from "@servo-map/shared";
import { KV_KEYS } from "../packages/worker/src/kv/keys";
import { cycleLows, priceDrops, selectDeliveries, type Alert, type HomeWatch, type Watch } from "../packages/worker/src/alerts/rules";

const env = (name: string) => process.env[name] ?? "";

// ── Cloudflare REST ──

async function cf(path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`https://api.cloudflare.com/client/v4/accounts/${env("CF_ACCOUNT_ID")}/${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${env("CF_API_TOKEN")}`, "Content-Type": "application/json", ...init.headers },
  });
}

async function d1<T = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<T[]> {
  const res = await cf(`d1/database/${env("D1_DATABASE_ID")}/query`, { method: "POST", body: JSON.stringify({ sql, params }) });
  const body = (await res.json()) as { success: boolean; errors?: { message: string }[]; result?: { results: T[] }[] };
  if (!body.success) throw new Error(`D1 query failed: ${body.errors?.map((e) => e.message).join("; ")}`);
  return body.result?.[0]?.results ?? [];
}

async function kvJson<T>(key: string): Promise<T | null> {
  const res = await cf(`storage/kv/namespaces/${env("CF_KV_NAMESPACE_ID")}/values/${encodeURIComponent(key)}`);
  return res.ok ? ((await res.json()) as T) : null;
}

// ── APNs ──

/** ES256 provider token, valid for up to an hour; one per run is enough. */
function apnsJwt(): string {
  const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const unsigned = `${b64({ alg: "ES256", kid: env("APNS_KEY_ID") })}.${b64({ iss: env("APNS_TEAM_ID"), iat: Math.floor(Date.now() / 1000) })}`;
  const sig = createSign("SHA256").update(unsigned).sign({ key: env("APNS_KEY").replace(/\\n/g, "\n"), dsaEncoding: "ieee-p1363" });
  return `${unsigned}.${sig.toString("base64url")}`;
}

/** Sends one alert to one device; returns false when APNs says the token is no longer valid. */
function push(host: string, jwt: string, device: string, alert: Alert): Promise<boolean> {
  return new Promise((resolve) => {
    const client = connect(`https://${host}`);
    client.on("error", () => resolve(true));
    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${device}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": env("APNS_TOPIC"),
      "apns-push-type": "alert",
      "apns-priority": "5",
      "apns-collapse-id": `${alert.kind}`,
    });
    let status = 0;
    req.on("response", (h) => { status = Number(h[":status"]); });
    req.on("end", () => { client.close(); resolve(status !== 410 && status !== 400); });
    req.on("error", () => { client.close(); resolve(true); });
    req.end(JSON.stringify({ aps: { alert: { title: alert.title, body: alert.body }, sound: "default" }, kind: alert.kind }));
    req.resume();
  });
}

// ── Job ──

async function main(): Promise<void> {
  const missing = ["CF_ACCOUNT_ID", "CF_API_TOKEN", "CF_KV_NAMESPACE_ID", "D1_DATABASE_ID", "APNS_KEY", "APNS_KEY_ID", "APNS_TEAM_ID", "APNS_TOPIC"].filter((n) => !env(n));
  if (missing.length) {
    console.log(`Alerts not configured (missing ${missing.join(", ")}); skipping.`);
    return;
  }
  const now = new Date();
  const day = now.toISOString().slice(0, 10);

  const watchRows = await d1<{ user_id: string; station_id: string; fuel: string | null; tank_litres: number | null }>(
    `SELECT s.user_id, s.station_id, c.fuel, c.tank_litres FROM saved_stations s
     JOIN alert_settings a ON a.user_id = s.user_id AND a.price_drop = 1
     LEFT JOIN cars c ON c.user_id = s.user_id`,
  );
  const homeRows = await d1<{ user_id: string; home_lat: number; home_lng: number; fuel: string | null }>(
    `SELECT a.user_id, a.home_lat, a.home_lng, c.fuel FROM alert_settings a LEFT JOIN cars c ON c.user_id = a.user_id
     WHERE a.cycle_low = 1 AND a.home_lat IS NOT NULL`,
  );
  if (!watchRows.length && !homeRows.length) {
    console.log("No one has alerts on.");
    return;
  }

  const watches: Watch[] = watchRows.map((r) => ({ userId: r.user_id, stationId: r.station_id, fuel: (r.fuel ?? "U91") as FuelType, tankLitres: r.tank_litres ?? 50 }));
  const states = new Set<AustralianState>([...watches.map((w) => w.stationId.split("-")[0] as AustralianState), "nsw"]);
  const stationsByState = new Map<AustralianState, Station[]>();
  for (const s of states) stationsByState.set(s, (await kvJson<Station[]>(KV_KEYS.stationsByState(s))) ?? []);
  const stations = new Map([...stationsByState.values()].flat().map((s) => [s.id, s]));

  const seenRows = await d1<{ station_id: string; fuel: string; price: number }>("SELECT station_id, fuel, price FROM station_prices_seen");
  const seen = new Map(seenRows.map((r) => [`${r.station_id}|${r.fuel}`, r.price]));

  const homes: HomeWatch[] = homeRows.map((r) => ({ userId: r.user_id, fuel: (r.fuel ?? "U91") as FuelType, home: { lat: r.home_lat, lng: r.home_lng } }));
  const history = (await kvJson<PriceSnapshot[]>(KV_KEYS.priceHistory("nsw"))) ?? [];
  const alerts = [...priceDrops(watches, seen, stations, day), ...cycleLows(homes, history, stationsByState.get("nsw") ?? [], day)];

  const settings = await d1<{ user_id: string; quiet_start: number; quiet_end: number }>("SELECT user_id, quiet_start, quiet_end FROM alert_settings");
  const quiet = new Map(settings.map((r) => [r.user_id, { start: r.quiet_start, end: r.quiet_end }]));
  const log = await d1<{ user_id: string; kind: string; key: string; sent_at: string }>(
    "SELECT user_id, kind, key, sent_at FROM alert_log WHERE sent_at >= ?1", [new Date(now.getTime() - 3 * 86_400_000).toISOString()]);
  const sentToday = new Set(log.filter((r) => r.sent_at.slice(0, 10) === day).map((r) => r.user_id));
  const alreadySent = new Set(log.map((r) => `${r.user_id}|${r.kind}|${r.key}`));
  const deliveries = selectDeliveries(alerts, now, quiet, sentToday, alreadySent);

  const jwt = apnsJwt();
  let sent = 0;
  for (const alert of deliveries) {
    const devices = await d1<{ token: string; environment: string }>("SELECT token, environment FROM devices WHERE user_id = ?1", [alert.userId]);
    for (const d of devices) {
      const host = d.environment === "development" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
      const valid = await push(host, jwt, d.token, alert);
      if (!valid) await d1("DELETE FROM devices WHERE token = ?1", [d.token]);
      else sent++;
    }
    await d1("INSERT OR IGNORE INTO alert_log (user_id, kind, key, sent_at) VALUES (?1, ?2, ?3, ?4)", [alert.userId, alert.kind, alert.key, now.toISOString()]);
  }

  // Remember today's prices at watched stations: the baseline for the next run's drops.
  for (const w of watches) {
    const price = stations.get(w.stationId)?.prices.find((p) => p.fuel === w.fuel)?.price;
    if (price === undefined) continue;
    await d1(
      `INSERT INTO station_prices_seen (station_id, fuel, price, seen_at) VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT (station_id, fuel) DO UPDATE SET price = ?3, seen_at = ?4`,
      [w.stationId, w.fuel, price, now.toISOString()],
    );
  }
  console.log(`Alerts: ${alerts.length} candidates, ${deliveries.length} chosen, ${sent} pushes sent.`);
}

main().catch((e) => {
  // An alert failure must never fail the ingest workflow it follows.
  console.error("Alerts failed:", e instanceof Error ? e.message : e);
});
