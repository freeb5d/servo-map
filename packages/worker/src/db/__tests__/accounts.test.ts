import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import type { ApiResponse, FillUpRecord, MeResponse, SessionResponse } from "@servo-map/shared";
import { Hono } from "hono";
import { createSqliteD1 } from "../__mocks__/sqlite-d1";
import { createAuthRoute } from "../../routes/auth";
import { meRoute } from "../../routes/me";
import { rsaKeyPair, signIdToken } from "../../auth/__mocks__/id-token";
import type { Env } from "../../env";

let env: Env;
let publicJwk: JsonWebKey;
let privateKey: CryptoKey;

const app = new Hono<{ Bindings: Env }>();
app.route("/auth", createAuthRoute(() => ({
  issuers: ["https://appleid.apple.com"],
  audiences: ["com.misoto22.servomap"],
  key: async () => publicJwk,
})));
app.route("/me", meRoute);

beforeAll(async () => {
  const pair = await rsaKeyPair();
  publicJwk = (await crypto.subtle.exportKey("jwk", pair.publicKey)) as JsonWebKey;
  privateKey = pair.privateKey;
});

beforeEach(() => {
  env = { DB: createSqliteD1(), SESSION_SECRET: "test-secret", KV: {} as KVNamespace, NSW_API_KEY: "", NSW_API_AUTH: "", QLD_API_TOKEN: "" };
});

async function signIn(sub: string, name?: string): Promise<string> {
  const identityToken = await signIdToken(
    { iss: "https://appleid.apple.com", aud: "com.misoto22.servomap", sub, exp: Math.floor(Date.now() / 1000) + 600 }, "k", privateKey);
  const res = await app.request("/auth/apple", { method: "POST", body: JSON.stringify({ identityToken, name }), headers: { "Content-Type": "application/json" } }, env);
  expect(res.status).toBe(200);
  return ((await res.json()) as ApiResponse<SessionResponse>).data.token;
}

const call = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, { ...init, headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } }, env);

const fill = (id: string): FillUpRecord => ({
  id, date: "2026-09-23T08:30:00+10:00", stationId: "nsw-1", stationName: "Metro Croydon", brand: "Metro Fuel",
  fuel: "U91", litres: 42.3, centsPerLitre: 225.9, areaAverage: 240.3,
});

describe("sign-in", () => {
  it("creates an account once per identity", async () => {
    const t1 = await signIn("apple-sub-1", "Henry");
    const t2 = await signIn("apple-sub-1");
    const me1 = ((await (await call("/me", t1)).json()) as ApiResponse<MeResponse>).data;
    const me2 = ((await (await call("/me", t2)).json()) as ApiResponse<MeResponse>).data;
    expect(me1.account.id).toBe(me2.account.id);
    expect(me1.account.name).toBe("Henry");
    expect(me1.alerts).toEqual({ priceDrop: false, cycleLow: false, quietStart: 22, quietEnd: 7 });
  });

  it("rejects a bad provider, a missing token and a forged one", async () => {
    expect((await app.request("/auth/facebook", { method: "POST", body: "{}" }, env)).status).toBe(404);
    expect((await app.request("/auth/apple", { method: "POST", body: "{}" }, env)).status).toBe(400);
    const res = await app.request("/auth/apple", { method: "POST", body: JSON.stringify({ identityToken: "a.b.c" }) }, env);
    expect(res.status).toBe(401);
  });
});

describe("/me", () => {
  it("needs a session", async () => {
    expect((await app.request("/me", {}, env)).status).toBe(401);
    expect((await call("/me", "not-a-token")).status).toBe(401);
  });

  it("syncs saved stations, fill-ups, car and alerts", async () => {
    const t = await signIn("s1");
    expect((await call("/me/saved", t, { method: "PUT", body: JSON.stringify({ stationIds: ["nsw-1", "nsw-2", "nsw-1"] }) })).status).toBe(204);
    expect((await call("/me/saved", t, { method: "PUT", body: JSON.stringify({ stationIds: ["nsw-2", "wa-9"] }) })).status).toBe(204);
    expect((await call("/me/fillups", t, { method: "PUT", body: JSON.stringify({ fillUps: [fill("f1"), fill("f2")] }) })).status).toBe(204);
    // Same id again replaces rather than duplicates.
    expect((await call("/me/fillups", t, { method: "PUT", body: JSON.stringify({ fillUps: [{ ...fill("f1"), litres: 40 }] }) })).status).toBe(204);
    expect((await call("/me/car", t, { method: "PUT", body: JSON.stringify({ name: "Corolla", body: "hatch", paint: "red", fuel: "U91", tankLitres: 50, catalogueTankLitres: 50, vehicleId: "toyota-corolla-2019" }) })).status).toBe(204);
    expect((await call("/me/alerts", t, { method: "PUT", body: JSON.stringify({ priceDrop: true, cycleLow: false, quietStart: 22, quietEnd: 7, home: { lat: -33.87654, lng: 151.21234 } }) })).status).toBe(204);

    const me = ((await (await call("/me", t)).json()) as ApiResponse<MeResponse>).data;
    expect(me.savedStationIds.sort()).toEqual(["nsw-2", "wa-9"]);
    expect(me.fillUps.map((f) => [f.id, f.litres])).toEqual(expect.arrayContaining([["f1", 40], ["f2", 42.3]]));
    expect(me.car).toMatchObject({ name: "Corolla", tankLitres: 50, vehicleId: "toyota-corolla-2019" });
    expect(me.alerts).toEqual({ priceDrop: true, cycleLow: false, quietStart: 22, quietEnd: 7, home: { lat: -33.88, lng: 151.21 } });
  });

  it("keeps each account's data to itself", async () => {
    const a = await signIn("alice");
    const b = await signIn("bob");
    await call("/me/fillups", a, { method: "PUT", body: JSON.stringify({ fillUps: [fill("shared-id")] }) });
    // Bob reusing Alice's fill-up id must not overwrite hers, and cannot delete it.
    await call("/me/fillups", b, { method: "PUT", body: JSON.stringify({ fillUps: [{ ...fill("shared-id"), litres: 1 }] }) });
    expect((await call("/me/fillups/shared-id", b, { method: "DELETE" })).status).toBe(404);
    const alice = ((await (await call("/me", a)).json()) as ApiResponse<MeResponse>).data;
    expect(alice.fillUps[0].litres).toBe(42.3);
    const bob = ((await (await call("/me", b)).json()) as ApiResponse<MeResponse>).data;
    expect(bob.fillUps).toEqual([]);
  });

  it("reports every invalid field at once", async () => {
    const t = await signIn("s2");
    const res = await call("/me/car", t, { method: "PUT", body: JSON.stringify({ name: "", body: "tank", paint: "red", fuel: "LPG", tankLitres: 5 }) });
    expect(res.status).toBe(400);
    const body = (await res.json()) as { errors: { field: string }[] };
    expect(body.errors.map((e) => e.field)).toEqual(["name", "body", "fuel", "tankLitres"]);
    expect((await call("/me/alerts", t, { method: "PUT", body: JSON.stringify({ priceDrop: true, cycleLow: false, quietStart: 22, quietEnd: 7, home: { lat: 40, lng: 0 } }) })).status).toBe(400);
    expect((await call("/me/devices/zz", t, { method: "PUT", body: "{}" })).status).toBe(400);
  });

  it("deletes the account and everything in it", async () => {
    const t = await signIn("leaver");
    await call("/me/saved", t, { method: "PUT", body: JSON.stringify({ stationIds: ["nsw-1"] }) });
    await call("/me/fillups", t, { method: "PUT", body: JSON.stringify({ fillUps: [fill("x")] }) });
    await call(`/me/devices/${"a".repeat(64)}`, t, { method: "PUT", body: JSON.stringify({ environment: "production" }) });
    expect((await call("/me", t, { method: "DELETE" })).status).toBe(204);
    expect((await call("/me", t)).status).toBe(401);
    for (const table of ["users", "saved_stations", "fillups", "devices"]) {
      const r = await env.DB!.prepare(`SELECT COUNT(*) AS n FROM ${table}`).first<{ n: number }>();
      expect(r?.n, table).toBe(0);
    }
  });
});
