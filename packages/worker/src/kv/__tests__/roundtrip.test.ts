import { describe, it, expect } from "vitest";
import type { Station } from "@servo-map/shared";
import { createMemoryKV } from "../__mocks__/memory-kv";
import { writeStations, writeBrands, writeMetadata } from "../write";
import {
  readStationsByState,
  readStationById,
  readBrands,
  readMetadata,
} from "../read";

const fixtureStations: Station[] = [
  {
    id: "nsw-1",
    name: "Caltex Sydney",
    brand: "Caltex",
    address: "1 Test St",
    suburb: "Sydney",
    state: "nsw",
    postcode: "2000",
    lat: -33.8688,
    lng: 151.2093,
    prices: [
      { fuel: "U91", price: 189.5, updated_at: "2026-03-28T00:00:00Z" },
      { fuel: "Diesel", price: 205.0, updated_at: "2026-03-28T00:00:00Z" },
    ],
  },
  {
    id: "nsw-2",
    name: "BP Parramatta",
    brand: "BP",
    address: "2 Other St",
    suburb: "Parramatta",
    state: "nsw",
    postcode: "2150",
    lat: -33.815,
    lng: 151.0,
    prices: [
      { fuel: "U91", price: 188.9, updated_at: "2026-03-28T00:00:00Z" },
    ],
  },
];

describe("KV round-trip", () => {
  it("writeStations → readStationsByState preserves data", async () => {
    const kv = createMemoryKV();
    await writeStations(kv, "nsw", fixtureStations);
    const out = await readStationsByState(kv, "nsw");
    expect(out).toEqual(fixtureStations);
  });

  it("readStationById resolves a station from its state chunk (no per-id keys)", async () => {
    const kv = createMemoryKV();
    await writeStations(kv, "nsw", fixtureStations);
    const one = await readStationById(kv, "nsw-1");
    expect(one).toEqual(fixtureStations[0]);
  });

  it("readStationById resolves a retired nsw- id to the station now filed under ACT", async () => {
    const kv = createMemoryKV();
    const act: Station = { ...fixtureStations[0], id: "act-18711", state: "act", postcode: "2913" };
    await writeStations(kv, "nsw", fixtureStations);
    await writeStations(kv, "act", [act]);

    expect(await readStationById(kv, "nsw-18711")).toEqual(act);
    expect(await readStationById(kv, "act-18711")).toEqual(act);
    // A current nsw- id still wins over the alias.
    expect(await readStationById(kv, "nsw-1")).toEqual(fixtureStations[0]);
    expect(await readStationById(kv, "nsw-99999")).toBeNull();
  });

  it("readStationById returns null for a missing id, unknown state, or junk", async () => {
    const kv = createMemoryKV();
    await writeStations(kv, "nsw", fixtureStations);
    expect(await readStationById(kv, "nsw-999")).toBeNull(); // valid state, no match
    expect(await readStationById(kv, "zz-1")).toBeNull(); // invalid state prefix
    expect(await readStationById(kv, "garbage")).toBeNull(); // no state prefix
  });

  it("readStationsByState returns [] for unknown state", async () => {
    const kv = createMemoryKV();
    const out = await readStationsByState(kv, "wa");
    expect(out).toEqual([]);
  });

  it("writeBrands stores and reads back", async () => {
    const kv = createMemoryKV();
    await writeBrands(kv, ["BP", "Caltex", "Shell"]);
    expect(await readBrands(kv)).toEqual(["BP", "Caltex", "Shell"]);
  });
});

describe("writeMetadata merge semantics", () => {
  it("preserves states that didn't update", async () => {
    const kv = createMemoryKV();
    await writeMetadata(kv, {
      nsw: { last_updated: "2026-03-28T00:00:00Z", station_count: 100 },
    });
    await writeMetadata(kv, {
      qld: { last_updated: "2026-03-28T00:15:00Z", station_count: 50 },
    });
    const meta = await readMetadata(kv);
    expect(meta.nsw).toBeDefined();
    expect(meta.qld).toBeDefined();
    expect(meta.nsw.station_count).toBe(100);
    expect(meta.qld.station_count).toBe(50);
  });

  it("overwrites a state when it does update", async () => {
    const kv = createMemoryKV();
    await writeMetadata(kv, {
      nsw: { last_updated: "2026-03-28T00:00:00Z", station_count: 100 },
    });
    await writeMetadata(kv, {
      nsw: { last_updated: "2026-03-28T00:15:00Z", station_count: 105 },
    });
    const meta = await readMetadata(kv);
    expect(meta.nsw.station_count).toBe(105);
    expect(meta.nsw.last_updated).toBe("2026-03-28T00:15:00Z");
  });
});
