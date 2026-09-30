import { Hono, type Context } from "hono";
import {
  BODY_TYPES,
  FUEL_TYPES,
  type AlertSettings,
  type ApiResponse,
  type CarProfile,
  type FillUpRecord,
  type MeResponse,
} from "@servo-map/shared";
import type { Env } from "../env";
import { verifySession } from "../auth/jwt";
import {
  deleteAccount,
  deleteFillUp,
  getAccount,
  loadMe,
  putDevice,
  putFillUps,
  setAlerts,
  setCar,
  setSaved,
} from "../db/accounts";

type Vars = { userId: string; db: D1Database };
type C = Context<{ Bindings: Env; Variables: Vars }>;

const fail = (c: C, status: 400 | 401 | 404, code: string, message: string) =>
  c.json({ status: "error", message, code }, status);

const isNum = (v: unknown, lo: number, hi: number): v is number => typeof v === "number" && Number.isFinite(v) && v >= lo && v <= hi;
const isStr = (v: unknown, max: number): v is string => typeof v === "string" && v.length > 0 && v.length <= max;

/** Field errors for one fill-up, or none. */
function fillUpErrors(f: Partial<FillUpRecord>, i: number): string[] {
  const e: string[] = [];
  if (!isStr(f.id, 64)) e.push(`fillUps[${i}].id`);
  if (!isStr(f.date, 40) || Number.isNaN(Date.parse(f.date))) e.push(`fillUps[${i}].date`);
  if (!isStr(f.stationId, 64)) e.push(`fillUps[${i}].stationId`);
  if (!isStr(f.stationName, 120)) e.push(`fillUps[${i}].stationName`);
  if (!isStr(f.brand, 80)) e.push(`fillUps[${i}].brand`);
  if (!FUEL_TYPES.includes(f.fuel as never)) e.push(`fillUps[${i}].fuel`);
  if (!isNum(f.litres, 0.1, 400)) e.push(`fillUps[${i}].litres`);
  if (!isNum(f.centsPerLitre, 50, 1000)) e.push(`fillUps[${i}].centsPerLitre`);
  if (f.areaAverage !== undefined && !isNum(f.areaAverage, 50, 1000)) e.push(`fillUps[${i}].areaAverage`);
  return e;
}

/** Everything under /api/v1/me acts for the signed-in account only. */
export const meRoute = new Hono<{ Bindings: Env; Variables: Vars }>();

meRoute.use("*", async (c, next) => {
  const { DB, SESSION_SECRET } = c.env;
  if (!DB || !SESSION_SECRET) {
    return c.json({ status: "error", message: "Accounts are not available yet", code: "ACCOUNTS_UNAVAILABLE" }, 503);
  }
  c.set("db", DB);
  const header = c.req.header("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  try {
    c.set("userId", await verifySession(token, SESSION_SECRET));
  } catch {
    return fail(c, 401, "UNAUTHENTICATED", "Sign in again");
  }
  c.header("Cache-Control", "private, no-store");
  await next();
});

// GET /api/v1/me
meRoute.get("/", async (c) => {
  const account = await getAccount(c.get("db"), c.get("userId"));
  if (!account) return fail(c, 401, "UNAUTHENTICATED", "Sign in again");
  return c.json({ status: "success", data: await loadMe(c.get("db"), account) } satisfies ApiResponse<MeResponse>);
});

// DELETE /api/v1/me — removes the account and everything in it (App Store 5.1.1(v)).
meRoute.delete("/", async (c) => {
  await deleteAccount(c.get("db"), c.get("userId"));
  return c.body(null, 204);
});

// PUT /api/v1/me/saved  { stationIds: string[] }
meRoute.put("/saved", async (c) => {
  const body = await c.req.json<{ stationIds?: unknown }>().catch(() => ({}) as { stationIds?: unknown });
  const ids = body.stationIds;
  if (!Array.isArray(ids) || ids.length > 200 || !ids.every((id) => isStr(id, 64))) {
    return fail(c, 400, "INVALID_SAVED", "stationIds must be up to 200 station ids");
  }
  await setSaved(c.get("db"), c.get("userId"), ids as string[]);
  return c.body(null, 204);
});

// PUT /api/v1/me/fillups  { fillUps: FillUpRecord[] } — adds or replaces by id
meRoute.put("/fillups", async (c) => {
  const body = await c.req.json<{ fillUps?: unknown }>().catch(() => ({}) as { fillUps?: unknown });
  const fills = body.fillUps;
  if (!Array.isArray(fills) || fills.length > 500) return fail(c, 400, "INVALID_FILLUPS", "fillUps must be a list of up to 500");
  const errors = fills.flatMap((f, i) => fillUpErrors(f as Partial<FillUpRecord>, i));
  if (errors.length) {
    return c.json({ status: "error", message: "Some fill-ups are invalid", code: "INVALID_FILLUPS", errors: errors.map((field) => ({ field, message: "Invalid value" })) }, 400);
  }
  await putFillUps(c.get("db"), c.get("userId"), fills as FillUpRecord[]);
  return c.body(null, 204);
});

// DELETE /api/v1/me/fillups/:id
meRoute.delete("/fillups/:id", async (c) => {
  const deleted = await deleteFillUp(c.get("db"), c.get("userId"), c.req.param("id"));
  return deleted ? c.body(null, 204) : fail(c, 404, "NOT_FOUND", "No such fill-up");
});

// PUT /api/v1/me/car  CarProfile
meRoute.put("/car", async (c) => {
  const car = await c.req.json<Partial<CarProfile>>().catch(() => ({}) as Partial<CarProfile>);
  const errors: string[] = [];
  if (!isStr(car.name, 60)) errors.push("name");
  if (!BODY_TYPES.includes(car.body as never)) errors.push("body");
  // Retired with the car drawings (decision 0008); still accepted from older app versions.
  if (car.paint !== undefined && !isStr(car.paint, 20)) errors.push("paint");
  if (!FUEL_TYPES.includes(car.fuel as never)) errors.push("fuel");
  if (!isNum(car.tankLitres, 20, 200) || !Number.isInteger(car.tankLitres)) errors.push("tankLitres");
  if (car.vehicleId !== undefined && !isStr(car.vehicleId, 80)) errors.push("vehicleId");
  if (errors.length) return c.json({ status: "error", message: "The car is invalid", code: "INVALID_CAR", errors: errors.map((field) => ({ field, message: "Invalid value" })) }, 400);
  await setCar(c.get("db"), c.get("userId"), car as CarProfile);
  return c.body(null, 204);
});

// PUT /api/v1/me/alerts  AlertSettings
meRoute.put("/alerts", async (c) => {
  const a = await c.req.json<Partial<AlertSettings>>().catch(() => ({}) as Partial<AlertSettings>);
  const errors: string[] = [];
  if (typeof a.priceDrop !== "boolean") errors.push("priceDrop");
  if (typeof a.cycleLow !== "boolean") errors.push("cycleLow");
  if (!isNum(a.quietStart, 0, 23) || !Number.isInteger(a.quietStart)) errors.push("quietStart");
  if (!isNum(a.quietEnd, 0, 23) || !Number.isInteger(a.quietEnd)) errors.push("quietEnd");
  if (a.home !== undefined && !(isNum(a.home?.lat, -44, -9) && isNum(a.home?.lng, 112, 154))) errors.push("home");
  if (errors.length) return c.json({ status: "error", message: "The alert settings are invalid", code: "INVALID_ALERTS", errors: errors.map((field) => ({ field, message: "Invalid value" })) }, 400);
  await setAlerts(c.get("db"), c.get("userId"), a as AlertSettings);
  return c.body(null, 204);
});

// PUT /api/v1/me/devices/:token  { environment }
meRoute.put("/devices/:token", async (c) => {
  const token = c.req.param("token");
  const body = await c.req.json<{ environment?: unknown }>().catch(() => ({}) as { environment?: unknown });
  if (!/^[0-9a-f]{64,200}$/.test(token)) return fail(c, 400, "INVALID_DEVICE", "The device token must be hex");
  const environment = body.environment === "development" ? "development" : "production";
  await putDevice(c.get("db"), c.get("userId"), token, environment);
  return c.body(null, 204);
});
