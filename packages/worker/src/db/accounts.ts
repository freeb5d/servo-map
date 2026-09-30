import type { Account, AlertSettings, CarProfile, FillUpRecord, MeResponse } from "@servo-map/shared";

/**
 * Account data in D1. Every query is parameterised; every function takes the user id it acts for,
 * so one account can never read or change another's rows.
 */

type Row = Record<string, unknown>;

const now = () => new Date().toISOString();

function toAccount(r: Row): Account {
  return {
    id: String(r.id),
    provider: r.provider as Account["provider"],
    email: (r.email as string | null) ?? undefined,
    name: (r.name as string | null) ?? undefined,
    picture: (r.picture as string | null) ?? undefined,
    createdAt: String(r.created_at),
  };
}

/** Finds the account for a provider identity, creating it on first sign-in. */
export async function upsertAccount(
  db: D1Database,
  identity: { provider: Account["provider"]; subject: string; email?: string; name?: string; picture?: string },
): Promise<Account> {
  const existing = await db
    .prepare("SELECT * FROM users WHERE provider = ?1 AND subject = ?2")
    .bind(identity.provider, identity.subject)
    .first<Row>();
  if (existing) {
    // Apple sends the name only on the very first sign-in; keep what we have. Email and photo follow the provider.
    const email = identity.email ?? existing.email;
    const picture = identity.picture ?? existing.picture;
    if (email !== existing.email || picture !== existing.picture) {
      await db.prepare("UPDATE users SET email = ?1, picture = ?2 WHERE id = ?3").bind(email ?? null, picture ?? null, existing.id).run();
      existing.email = email;
      existing.picture = picture;
    }
    return toAccount(existing);
  }
  const id = crypto.randomUUID();
  const createdAt = now();
  await db
    .prepare("INSERT INTO users (id, provider, subject, email, name, picture, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)")
    .bind(id, identity.provider, identity.subject, identity.email ?? null, identity.name ?? null, identity.picture ?? null, createdAt)
    .run();
  return { id, provider: identity.provider, email: identity.email, name: identity.name, picture: identity.picture, createdAt };
}

export async function getAccount(db: D1Database, userId: string): Promise<Account | null> {
  const r = await db.prepare("SELECT * FROM users WHERE id = ?1").bind(userId).first<Row>();
  return r ? toAccount(r) : null;
}

/** Everything synced for an account, in one read per table. */
export async function loadMe(db: D1Database, account: Account): Promise<MeResponse> {
  const [saved, fills, car, alerts] = await db.batch<Row>([
    db.prepare("SELECT station_id FROM saved_stations WHERE user_id = ?1 ORDER BY created_at").bind(account.id),
    db.prepare("SELECT * FROM fillups WHERE user_id = ?1 ORDER BY date DESC").bind(account.id),
    db.prepare("SELECT * FROM cars WHERE user_id = ?1").bind(account.id),
    db.prepare("SELECT * FROM alert_settings WHERE user_id = ?1").bind(account.id),
  ]);
  const c = car.results[0];
  const a = alerts.results[0];
  return {
    account,
    savedStationIds: saved.results.map((r) => String(r.station_id)),
    fillUps: fills.results.map(toFillUp),
    car: c
      ? {
          vehicleId: (c.vehicle_id as string | null) ?? undefined,
          name: String(c.name),
          body: c.body as CarProfile["body"],
          paint: String(c.paint),
          fuel: c.fuel as CarProfile["fuel"],
          tankLitres: Number(c.tank_litres),
          catalogueTankLitres: c.catalogue_tank_litres == null ? undefined : Number(c.catalogue_tank_litres),
        }
      : undefined,
    alerts: a
      ? {
          priceDrop: a.price_drop === 1,
          cycleLow: a.cycle_low === 1,
          quietStart: Number(a.quiet_start),
          quietEnd: Number(a.quiet_end),
          home: a.home_lat == null ? undefined : { lat: Number(a.home_lat), lng: Number(a.home_lng) },
        }
      : { priceDrop: false, cycleLow: false, quietStart: 22, quietEnd: 7 },
  };
}

function toFillUp(r: Row): FillUpRecord {
  return {
    id: String(r.id),
    date: String(r.date),
    stationId: String(r.station_id),
    stationName: String(r.station_name),
    brand: String(r.brand),
    fuel: r.fuel as FillUpRecord["fuel"],
    litres: Number(r.litres),
    centsPerLitre: Number(r.cents_per_litre),
    areaAverage: r.area_average == null ? undefined : Number(r.area_average),
  };
}

/** Replaces the saved list with `ids`, keeping when each surviving station was first saved. */
export async function setSaved(db: D1Database, userId: string, ids: string[]): Promise<void> {
  const unique = [...new Set(ids)];
  const stmts = [
    db.prepare(`DELETE FROM saved_stations WHERE user_id = ?1 AND station_id NOT IN (SELECT value FROM json_each(?2))`)
      .bind(userId, JSON.stringify(unique)),
    ...unique.map((id) =>
      db.prepare("INSERT OR IGNORE INTO saved_stations (user_id, station_id, created_at) VALUES (?1, ?2, ?3)").bind(userId, id, now()),
    ),
  ];
  await db.batch(stmts);
}

/** Adds or replaces fill-ups by id (the device's UUIDs), so uploading the same log twice is harmless. */
export async function putFillUps(db: D1Database, userId: string, fills: FillUpRecord[]): Promise<void> {
  if (!fills.length) return;
  await db.batch(
    fills.map((f) =>
      db
        .prepare(
          `INSERT INTO fillups (id, user_id, date, station_id, station_name, brand, fuel, litres, cents_per_litre, area_average)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
           ON CONFLICT (id) DO UPDATE SET date = ?3, station_id = ?4, station_name = ?5, brand = ?6, fuel = ?7,
             litres = ?8, cents_per_litre = ?9, area_average = ?10
           WHERE fillups.user_id = ?2`,
        )
        .bind(f.id, userId, f.date, f.stationId, f.stationName, f.brand, f.fuel, f.litres, f.centsPerLitre, f.areaAverage ?? null),
    ),
  );
}

export async function deleteFillUp(db: D1Database, userId: string, id: string): Promise<boolean> {
  const r = await db.prepare("DELETE FROM fillups WHERE id = ?1 AND user_id = ?2").bind(id, userId).run();
  return (r.meta.changes ?? 0) > 0;
}

export async function setCar(db: D1Database, userId: string, car: CarProfile): Promise<void> {
  await db
    .prepare(
      `INSERT INTO cars (user_id, vehicle_id, name, body, paint, fuel, tank_litres, catalogue_tank_litres, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
       ON CONFLICT (user_id) DO UPDATE SET vehicle_id = ?2, name = ?3, body = ?4, paint = ?5, fuel = ?6,
         tank_litres = ?7, catalogue_tank_litres = ?8, updated_at = ?9`,
    )
    .bind(userId, car.vehicleId ?? null, car.name, car.body, car.paint, car.fuel, car.tankLitres, car.catalogueTankLitres ?? null, now())
    .run();
}

export async function setAlerts(db: D1Database, userId: string, a: AlertSettings): Promise<void> {
  // About a kilometre: enough to find nearby prices, not enough to find a house.
  const round = (v: number) => Math.round(v * 100) / 100;
  await db
    .prepare(
      `INSERT INTO alert_settings (user_id, price_drop, cycle_low, quiet_start, quiet_end, home_lat, home_lng, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
       ON CONFLICT (user_id) DO UPDATE SET price_drop = ?2, cycle_low = ?3, quiet_start = ?4, quiet_end = ?5,
         home_lat = ?6, home_lng = ?7, updated_at = ?8`,
    )
    .bind(userId, a.priceDrop ? 1 : 0, a.cycleLow ? 1 : 0, a.quietStart, a.quietEnd,
      a.home ? round(a.home.lat) : null, a.home ? round(a.home.lng) : null, now())
    .run();
}

export async function putDevice(db: D1Database, userId: string, token: string, environment: "production" | "development"): Promise<void> {
  await db
    .prepare(
      `INSERT INTO devices (token, user_id, environment, updated_at) VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT (token) DO UPDATE SET user_id = ?2, environment = ?3, updated_at = ?4`,
    )
    .bind(token, userId, environment, now())
    .run();
}

/** Removes the account and every row that belongs to it, table by table rather than relying on cascades. */
export async function deleteAccount(db: D1Database, userId: string): Promise<void> {
  const tables = ["saved_stations", "fillups", "cars", "alert_settings", "devices", "alert_log"];
  await db.batch([
    ...tables.map((t) => db.prepare(`DELETE FROM ${t} WHERE user_id = ?1`).bind(userId)),
    db.prepare("DELETE FROM users WHERE id = ?1").bind(userId),
  ]);
}
