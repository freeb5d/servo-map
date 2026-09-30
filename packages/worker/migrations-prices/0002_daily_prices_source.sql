-- Marks where a daily_prices row came from (decision 0006): 'live' rows are the ingest's own
-- end-of-day snapshots; 'history' rows are rebuilt from a state's published price-history files
-- by scripts/backfill-daily-prices.py, and may be rebuilt again when a later file is published.
ALTER TABLE daily_prices ADD COLUMN source TEXT NOT NULL DEFAULT 'live' CHECK (source IN ('live', 'history'));
