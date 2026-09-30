-- ServoMap accounts (decision 0004). One row per person; everything else hangs off users.id.
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL CHECK (provider IN ('apple', 'google')),
  subject TEXT NOT NULL,
  email TEXT,
  name TEXT,
  -- Profile photo URL from Google; Apple provides none.
  picture TEXT,
  created_at TEXT NOT NULL,
  UNIQUE (provider, subject)
);

CREATE TABLE saved_stations (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  station_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, station_id)
);
CREATE INDEX saved_stations_station ON saved_stations (station_id);

CREATE TABLE fillups (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  station_id TEXT NOT NULL,
  station_name TEXT NOT NULL,
  brand TEXT NOT NULL,
  fuel TEXT NOT NULL,
  litres REAL NOT NULL,
  cents_per_litre REAL NOT NULL,
  area_average REAL
);
CREATE INDEX fillups_user ON fillups (user_id, date);

CREATE TABLE cars (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id TEXT,
  name TEXT NOT NULL,
  body TEXT NOT NULL,
  paint TEXT NOT NULL,
  fuel TEXT NOT NULL,
  tank_litres INTEGER NOT NULL,
  catalogue_tank_litres INTEGER,
  updated_at TEXT NOT NULL
);

CREATE TABLE alert_settings (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  price_drop INTEGER NOT NULL DEFAULT 0,
  cycle_low INTEGER NOT NULL DEFAULT 0,
  quiet_start INTEGER NOT NULL DEFAULT 22,
  quiet_end INTEGER NOT NULL DEFAULT 7,
  -- Rounded to ~1 km so the server never holds an exact home position.
  home_lat REAL,
  home_lng REAL,
  updated_at TEXT NOT NULL
);

CREATE TABLE devices (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  environment TEXT NOT NULL CHECK (environment IN ('production', 'development')),
  updated_at TEXT NOT NULL
);

-- What was sent, so a user gets at most one alert a day and never the same one twice.
CREATE TABLE alert_log (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  key TEXT NOT NULL,
  sent_at TEXT NOT NULL,
  PRIMARY KEY (user_id, kind, key)
);

-- The last price the alert job saw at each saved station, so it can tell a drop from a steady price.
CREATE TABLE station_prices_seen (
  station_id TEXT NOT NULL,
  fuel TEXT NOT NULL,
  price REAL NOT NULL,
  seen_at TEXT NOT NULL,
  PRIMARY KEY (station_id, fuel)
);
