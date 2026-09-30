# /// script
# requires-python = ">=3.12"
# dependencies = ["openpyxl>=3.1"]
# ///
"""Rebuild daily state price snapshots from published price-history files (decision 0006).

The live series (KV history:{state}, D1 daily_prices) holds, for each UTC date, the prices in
effect at that day's last ingest run, per fuel: min, avg, max and station count. When the ingest
missed days, the states' own history files can rebuild them:

  NSW / ACT  FuelCheck monthly price history (data.nsw.gov.au, dataset fuel-check), every change
  QLD        Queensland Fuel Prices monthly files (data.qld.gov.au, fuel-price-reporting-<year>)
  WA         FuelWatch monthly retail files (one price per station, fuel and day)

Accuracy, checked against 50 live NSW days and 5 live WA days on 2026-09-30:
  - WA is exact to within rounding.
  - For NSW, avg is within 1.1c (median 0.3) and station_count is within ~2%.
  - A change log cannot say when a station stopped listing a fuel, so NSW/ACT/QLD min comes from
    prices updated in the last 14 days (median error 0), and max from every carried-forward price.
    Charts use avg, and iOS also uses min.
A third source, for days no official file covers yet, is the daily state aggregates published by
github.com/jande425/aus-fuel-data-public (data/history/<state>.json, per city since 2025-12-25),
built from the same government feeds. Against 320 live NSW days its avg is within 0.2c (median)
and min matches; its "samples" run ~14% below our station_count. Use it only for states whose
feed licence allows it (NSW FuelCheck covers NSW, ACT and TAS), and pin the commit.

Only stations in today's live feed are counted for NSW/ACT, since delisted stations would
otherwise carry their last price for ever. QLD's 999.9c means "not available" and withdraws the
station's price; prices outside PLAUSIBLE_CENTS (typos such as 28.8c) are skipped, and min ignores
placeholder-looking prices below LOW_OUTLIER x the day's median (QLD's 99.9c).

Usage:
  uv run scripts/backfill-daily-prices.py rebuild STATE FROM TO FILE... > rows.json
  uv run scripts/backfill-daily-prices.py aggregate STATE FROM TO HISTORY_JSON > rows.json
  uv run scripts/backfill-daily-prices.py apply rows.json [--replace] [--kv] [--provenance TEXT]
apply upserts rows into D1 daily_prices with source='history'. It never overwrites a 'live' row
unless --replace is given, which replaces whole days. --kv also merges the rows into KV
history:{state}, capped at 90 days like the ingest. Env: CF_ACCOUNT_ID, CF_API_TOKEN,
D1_PRICES_DATABASE_ID, CF_KV_NAMESPACE_ID.
"""
import csv
import json
import math
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

UTC, SYDNEY = ZoneInfo("UTC"), ZoneInfo("Australia/Sydney")
# Mirrors packages/worker/src/utils/fuel-map.ts and PRICE_HISTORY_MAX_DAYS in kv/keys.ts.
NSW_FUEL = {"E10": "E10", "U91": "U91", "P95": "U95", "P98": "U98", "DL": "Diesel"}
QLD_FUEL = {"Unleaded": "U91", "PULP 95/96 RON": "U95", "PULP 98 RON": "U98", "e10": "E10", "Diesel": "Diesel"}
WA_FUEL = {"ULP": "U91", "PULP": "U95", "98 RON": "U98", "Diesel": "Diesel"}
HISTORY_MAX_DAYS = 90
FRESH_FOR_MIN = timedelta(days=14)
PLAUSIBLE_CENTS = (50.0, 900.0)
LOW_OUTLIER = 0.6
UNAVAILABLE_CENTS = 999.0
ACT_ADDRESS = re.compile(r"\bACT\s+\d{4}\s*$", re.I)
API = "https://api.servo-map.com/api/v1"


def js_round1(x: float) -> float:
    """Math.round(x * 10) / 10, as computeDailySnapshots rounds avg."""
    return math.floor(x * 10 + 0.5) / 10


def get_json(url: str, token: str | None = None, method: str = "GET", body: bytes | None = None):
    req = urllib.request.Request(url, data=body, method=method, headers={"User-Agent": "servo-map-backfill"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as res:
        return json.loads(res.read() or b"null")


# ── Reading the history files ──

def nsw_rows(path):
    if path.endswith(".csv"):
        with open(path, newline="", encoding="utf-8-sig") as f:
            reader = csv.reader(f)
            next(reader)
            for name, address, _suburb, _pc, _brand, code, when, price in reader:
                yield name, address, code, datetime.fromisoformat(when), float(price)
    else:
        import openpyxl

        rows = openpyxl.load_workbook(path, read_only=True).worksheets[0].iter_rows(values_only=True)
        next(rows)
        for name, address, _suburb, _pc, _brand, code, when, price in rows:
            if when is None or price is None:
                continue
            yield name, address, code, when if isinstance(when, datetime) else datetime.fromisoformat(when), float(price)


def live_station_keys(states):
    keys = set()
    for state in states:
        offset = 0
        while True:
            page = get_json(f"{API}/stations?state={state}&limit=500&offset={offset}")
            keys |= {(s["name"].strip().lower(), s["address"].strip().lower()) for s in page["data"]}
            offset += 500
            if offset >= page["meta"]["total"]:
                break
    return keys


def nsw_changes(paths, state):
    """FuelCheck files carry NSW and ACT; 'nsw' keeps both, as the NSW series did before 2026-09-30."""
    live = live_station_keys(["nsw", "act"])
    changes = {}
    for path in paths:
        for name, address, code, when, price in nsw_rows(path):
            fuel = NSW_FUEL.get(code)
            key = (str(name).strip().lower(), str(address).strip().lower())
            if not fuel or key not in live or (state == "act" and not ACT_ADDRESS.search(key[1])):
                continue
            changes.setdefault((key, fuel), []).append((when.replace(tzinfo=SYDNEY).astimezone(UTC), price))
    return changes


def qld_changes(paths):
    changes = {}
    for path in paths:
        with open(path, newline="", encoding="utf-8-sig") as f:
            for r in csv.DictReader(f):
                fuel = QLD_FUEL.get(r["Fuel_Type"])
                if fuel and r["Price"]:
                    when = datetime.strptime(r["TransactionDateutc"], "%d/%m/%Y %H:%M").replace(tzinfo=UTC)
                    cents = int(r["Price"]) / 10
                    # None withdraws the price: the station has stopped listing this fuel.
                    price = None if cents >= UNAVAILABLE_CENTS else cents
                    changes.setdefault((r["SiteId"], fuel), []).append((when, price))
    return changes


def wa_prices(paths):
    prices = {}
    for path in paths:
        with open(path, newline="", encoding="utf-8-sig") as f:
            for r in csv.DictReader(f):
                fuel = WA_FUEL.get(r["PRODUCT_DESCRIPTION"])
                price = float(r["PRODUCT_PRICE"])
                if fuel and PLAUSIBLE_CENTS[0] <= price <= PLAUSIBLE_CENTS[1]:
                    day = datetime.strptime(r["PUBLISH_DATE"], "%d/%m/%Y").date()
                    prices.setdefault(day, {}).setdefault(fuel, []).append(price)
    return prices


# ── Snapshots ──

def snapshot(state, day, by_fuel, fresh_by_fuel=None):
    rows = []
    for fuel, prices in sorted(by_fuel.items()):
        fresh = (fresh_by_fuel or {}).get(fuel) or prices
        if fresh_by_fuel is not None:
            floor = LOW_OUTLIER * sorted(prices)[len(prices) // 2]
            fresh = [p for p in fresh if p >= floor] or fresh
        rows.append({"state": state, "date": day.isoformat(), "fuel": fuel, "min": min(fresh),
                     "avg": js_round1(sum(prices) / len(prices)), "max": max(prices), "station_count": len(prices)})
    return rows


def rebuild_from_changes(state, changes, day):
    cutoff = datetime.combine(day, datetime.max.time(), tzinfo=UTC)
    by_fuel, fresh = {}, {}
    for (_key, fuel), series in changes.items():
        current = None
        for when, price in series:
            if when > cutoff:
                break
            current = (when, price)
        if current and current[1] is not None and PLAUSIBLE_CENTS[0] <= current[1] <= PLAUSIBLE_CENTS[1]:
            by_fuel.setdefault(fuel, []).append(current[1])
            if cutoff - current[0] <= FRESH_FOR_MIN:
                fresh.setdefault(fuel, []).append(current[1])
    return snapshot(state, day, by_fuel, fresh)


def rebuild(state, start, end, paths):
    if state == "wa":
        prices = wa_prices(paths)
        # At 23:59 UTC it is already the next day in Perth, past FuelWatch's 6 am switch.
        build = lambda d: snapshot("wa", d, prices.get(d + timedelta(days=1), {}))
    else:
        changes = qld_changes(paths) if state == "qld" else nsw_changes(paths, state)
        for series in changes.values():
            series.sort(key=lambda change: change[0])
        build = lambda d: rebuild_from_changes(state, changes, d)
    rows, day = [], start
    while day <= end:
        rows += build(day)
        day += timedelta(days=1)
    return rows


def from_aggregate(state, start, end, path):
    """Combines an aggregator's per-city daily figures into state rows (samples-weighted avg)."""
    fuels = {"U91": "U91", "U95": "U95", "U98": "U98", "E10": "E10", "Diesel": "Diesel"}
    combined = {}
    for days in json.load(open(path))["history"].values():
        for day, by_fuel in days.items():
            if not start.isoformat() <= day <= end.isoformat():
                continue
            for name, v in by_fuel.items():
                fuel = fuels.get(name)
                if not fuel or not v.get("samples"):
                    continue
                c = combined.setdefault((day, fuel), {"sum": 0.0, "n": 0, "min": math.inf, "max": -math.inf})
                c["sum"] += v["avg"] * v["samples"]
                c["n"] += v["samples"]
                c["min"] = min(c["min"], v["min"])
                c["max"] = max(c["max"], v["max"])
    return [{"state": state, "date": day, "fuel": fuel, "min": c["min"], "avg": js_round1(c["sum"] / c["n"]),
             "max": c["max"], "station_count": c["n"]} for (day, fuel), c in sorted(combined.items())]


# ── Writing ──

def d1(sql, params):
    url = f"https://api.cloudflare.com/client/v4/accounts/{os.environ['CF_ACCOUNT_ID']}/d1/database/{os.environ['D1_PRICES_DATABASE_ID']}/query"
    body = get_json(url, os.environ["CF_API_TOKEN"], "POST", json.dumps({"sql": sql, "params": params}).encode())
    if not body["success"]:
        raise SystemExit(f"D1 failed: {body['errors']}")
    return body["result"][0]


def kv_url(key):
    from urllib.parse import quote
    return f"https://api.cloudflare.com/client/v4/accounts/{os.environ['CF_ACCOUNT_ID']}/storage/kv/namespaces/{os.environ['CF_KV_NAMESPACE_ID']}/values/{quote(key, safe='')}"


def apply(rows, replace, kv, provenance):
    by_state = {}
    for r in rows:
        by_state.setdefault(r["state"], []).append(r)
    for state, state_rows in by_state.items():
        dates = sorted({r["date"] for r in state_rows})
        if replace:
            d1("DELETE FROM daily_prices WHERE state = ?1 AND date IN (SELECT value FROM json_each(?2))",
               [state, json.dumps(dates)])
        packed = [[r["fuel"], r["date"], r["min"], r["avg"], r["max"], r["station_count"]] for r in state_rows]
        res = d1("""INSERT INTO daily_prices (state, fuel, date, min, avg, max, station_count, source, provenance)
SELECT ?1, json_extract(value, '$[0]'), json_extract(value, '$[1]'), json_extract(value, '$[2]'),
       json_extract(value, '$[3]'), json_extract(value, '$[4]'), json_extract(value, '$[5]'), 'history', ?3
FROM json_each(?2) WHERE true
ON CONFLICT (state, fuel, date) DO UPDATE SET min = excluded.min, avg = excluded.avg, max = excluded.max,
  station_count = excluded.station_count, provenance = excluded.provenance
WHERE daily_prices.source = 'history'""", [state, json.dumps(packed), provenance])
        print(f"{state}: D1 {len(dates)} days, rows_written={res['meta'].get('rows_written')}", file=sys.stderr)
        if kv:
            merge_kv(state, state_rows, replace)


def merge_kv(state, state_rows, replace):
    token = os.environ["CF_API_TOKEN"]
    key = f"history:{state}"
    req = urllib.request.Request(kv_url(key), headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            existing = json.loads(res.read())
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
        existing = []
    new_dates = {r["date"] for r in state_rows}
    have = {s["date"] for s in existing}
    keep = [s for s in existing if not (replace and s["date"] in new_dates)]
    kept_dates = {s["date"] for s in keep}
    added = [{k: r[k] for k in ("date", "fuel", "min", "avg", "max", "station_count")}
             for r in state_rows if r["date"] not in kept_dates]
    merged = sorted(keep + added, key=lambda s: (s["date"], s["fuel"]))
    dates = sorted({s["date"] for s in merged})
    if len(dates) > HISTORY_MAX_DAYS:
        merged = [s for s in merged if s["date"] >= dates[-HISTORY_MAX_DAYS]]
    put = urllib.request.Request(kv_url(key), data=json.dumps(merged).encode(), method="PUT",
                                 headers={"Authorization": f"Bearer {token}"})
    urllib.request.urlopen(put, timeout=60).read()
    print(f"{state}: KV {len(have)} -> {len({s['date'] for s in merged})} days "
          f"({len({r['date'] for r in added})} added)", file=sys.stderr)


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "rebuild" and len(sys.argv) >= 6:
        state, start, end = sys.argv[2], date.fromisoformat(sys.argv[3]), date.fromisoformat(sys.argv[4])
        json.dump(rebuild(state, start, end, sys.argv[5:]), sys.stdout)
    elif command == "aggregate" and len(sys.argv) == 6:
        state, start, end = sys.argv[2], date.fromisoformat(sys.argv[3]), date.fromisoformat(sys.argv[4])
        json.dump(from_aggregate(state, start, end, sys.argv[5]), sys.stdout)
    elif command == "apply" and len(sys.argv) >= 3:
        args = sys.argv[3:]
        provenance = args[args.index("--provenance") + 1] if "--provenance" in args else None
        apply(json.load(open(sys.argv[2])), "--replace" in args, "--kv" in args, provenance)
    else:
        raise SystemExit(__doc__)
