-- Where a 'history' row's numbers came from (decision 0006), e.g. a state's history file or a
-- third-party aggregate pinned to a commit. NULL for 'live' rows, which the ingest wrote itself.
ALTER TABLE daily_prices ADD COLUMN provenance TEXT;

UPDATE daily_prices SET provenance = 'data.nsw.gov.au fuel-check monthly price history'
WHERE source = 'history' AND state IN ('nsw', 'act');
UPDATE daily_prices SET provenance = 'data.qld.gov.au fuel-price-reporting-2026'
WHERE source = 'history' AND state = 'qld';
UPDATE daily_prices SET provenance = 'FuelWatch monthly retail history'
WHERE source = 'history' AND state = 'wa';
