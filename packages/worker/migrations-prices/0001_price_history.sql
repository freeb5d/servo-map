-- ServoMap price history (decision 0006). Public price data only; accounts live in servo-map-accounts.
-- Every table is WITHOUT ROWID and has no secondary index: on D1 each index entry is another billed
-- row write, and the free plan allows 100,000 a day. Queries by state use the "{state}-" id prefix.

-- One row per station, keyed by the id the API serves (Station.id, "{state}-{source id}").
CREATE TABLE stations (
  id TEXT PRIMARY KEY,
  state TEXT NOT NULL,
  name TEXT NOT NULL,
  brand TEXT NOT NULL,
  address TEXT NOT NULL,
  suburb TEXT NOT NULL,
  -- Empty where the source has none (WA FuelWatch).
  postcode TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  first_seen_at TEXT NOT NULL,
  -- A date, not a time, so an unchanged station is rewritten at most once a day.
  last_seen_on TEXT NOT NULL
) WITHOUT ROWID;

-- The latest price per station and fuel. Rewritten only when the price itself changes.
CREATE TABLE current_prices (
  station_id TEXT NOT NULL,
  fuel TEXT NOT NULL,
  -- Cents per litre.
  price REAL NOT NULL,
  -- The source's own timestamp; WA publishes none, so its adapter uses the fetch time.
  reported_at TEXT NOT NULL,
  -- The ingest run that first saw this price.
  observed_at TEXT NOT NULL,
  PRIMARY KEY (station_id, fuel)
) WITHOUT ROWID;

-- Every price a station has shown, appended by the triggers below. Never updated.
CREATE TABLE price_changes (
  station_id TEXT NOT NULL,
  fuel TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  price REAL NOT NULL,
  reported_at TEXT NOT NULL,
  PRIMARY KEY (station_id, fuel, observed_at)
) WITHOUT ROWID;

CREATE TRIGGER current_prices_first_seen AFTER INSERT ON current_prices
BEGIN
  INSERT OR IGNORE INTO price_changes (station_id, fuel, observed_at, price, reported_at)
  VALUES (NEW.station_id, NEW.fuel, NEW.observed_at, NEW.price, NEW.reported_at);
END;

CREATE TRIGGER current_prices_changed AFTER UPDATE OF price ON current_prices
WHEN NEW.price <> OLD.price
BEGIN
  INSERT OR IGNORE INTO price_changes (station_id, fuel, observed_at, price, reported_at)
  VALUES (NEW.station_id, NEW.fuel, NEW.observed_at, NEW.price, NEW.reported_at);
END;

-- Daily min/avg/max per state and fuel (PriceSnapshot), kept without the KV series' 90-day cap.
CREATE TABLE daily_prices (
  state TEXT NOT NULL,
  fuel TEXT NOT NULL,
  date TEXT NOT NULL,
  min REAL NOT NULL,
  avg REAL NOT NULL,
  max REAL NOT NULL,
  station_count INTEGER NOT NULL,
  PRIMARY KEY (state, fuel, date)
) WITHOUT ROWID;

-- One row per state per ingest run, so gaps and failures are visible after the fact.
CREATE TABLE ingest_runs (
  run_at TEXT NOT NULL,
  state TEXT NOT NULL,
  -- written: stored; guarded: fetched but below the retention guard; failed: the adapter threw.
  status TEXT NOT NULL CHECK (status IN ('written', 'guarded', 'failed')),
  station_count INTEGER NOT NULL,
  -- D1 rows this run wrote for the state, to watch the free-plan write budget.
  rows_written INTEGER NOT NULL DEFAULT 0,
  detail TEXT,
  PRIMARY KEY (run_at, state)
) WITHOUT ROWID;
