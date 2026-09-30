import { FUEL_TYPES, type FuelType } from "./fuel";

/** Body shapes the apps draw a car as (decision 0004); every catalogue model maps to one. */
export const BODY_TYPES = ["hatch", "sedan", "wagon", "suv", "ute", "van"] as const;
export type BodyType = (typeof BODY_TYPES)[number];

/** One model generation in the shared car catalogue. */
export interface Vehicle {
  /** Stable id, e.g. `toyota-corolla-2019`. */
  id: string;
  make: string;
  model: string;
  fromYear: number;
  /** Last model year; absent while still on sale. */
  toYear?: number;
  body: BodyType;
  /** Recommended fuel of the most common variant. */
  fuel: FuelType;
  tankLitres: number;
  /** Where the tank capacity was read. */
  source: string;
}

const COLUMNS = ["make", "model", "from_year", "to_year", "body", "fuel", "tank_litres", "source"] as const;

function slug(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

/** Splits one CSV line, honouring double-quoted fields. */
function splitCsvLine(line: string): string[] {
  const out: string[] = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quoted) {
      if (ch === '"' && line[i + 1] === '"') { field += '"'; i++; }
      else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ",") { out.push(field); field = ""; }
    else field += ch;
  }
  out.push(field);
  return out.map((f) => f.trim());
}

/**
 * Parses `data/vehicles.csv`. Throws on a malformed row so a bad edit fails the build instead of
 * shipping a car with no tank size.
 */
export function parseVehicles(csv: string): Vehicle[] {
  const lines = csv.split(/\r?\n/).filter((l) => l.trim() !== "");
  const header = splitCsvLine(lines[0] ?? "");
  if (COLUMNS.some((c, i) => header[i] !== c)) {
    throw new Error(`vehicles.csv header must be: ${COLUMNS.join(",")}`);
  }
  const seen = new Set<string>();
  return lines.slice(1).map((line, i) => {
    const [make, model, from, to, body, fuel, tank, source] = splitCsvLine(line);
    const row = i + 2;
    const fromYear = Number(from);
    const toYear = to ? Number(to) : undefined;
    const tankLitres = Number(tank);
    if (!make || !model) throw new Error(`vehicles.csv row ${row}: make and model are required`);
    if (!Number.isInteger(fromYear) || fromYear < 1990) throw new Error(`vehicles.csv row ${row}: bad from_year "${from}"`);
    if (toYear !== undefined && (!Number.isInteger(toYear) || toYear < fromYear)) throw new Error(`vehicles.csv row ${row}: bad to_year "${to}"`);
    if (!(BODY_TYPES as readonly string[]).includes(body)) throw new Error(`vehicles.csv row ${row}: bad body "${body}"`);
    if (!(FUEL_TYPES as readonly string[]).includes(fuel)) throw new Error(`vehicles.csv row ${row}: bad fuel "${fuel}"`);
    if (!Number.isInteger(tankLitres) || tankLitres < 20 || tankLitres > 200) throw new Error(`vehicles.csv row ${row}: bad tank_litres "${tank}"`);
    if (!/^https?:\/\//.test(source)) throw new Error(`vehicles.csv row ${row}: source must be a URL`);
    let id = slug(`${make} ${model} ${fromYear}`);
    while (seen.has(id)) id += "-b";
    seen.add(id);
    return { id, make, model, fromYear, toYear, body: body as BodyType, fuel: fuel as FuelType, tankLitres, source };
  });
}

/**
 * Catalogue search for the picker: every word of `query` must match the make, model or a year in
 * the generation's range. Results come sorted by make, model, then newest first.
 */
export function searchVehicles(vehicles: readonly Vehicle[], query: string, limit = 20): Vehicle[] {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  const matches = vehicles.filter((v) => {
    const text = `${v.make} ${v.model}`.toLowerCase();
    return words.every((w) => {
      if (/^\d{4}$/.test(w)) {
        const year = Number(w);
        return year >= v.fromYear && year <= (v.toYear ?? 9999);
      }
      return text.includes(w);
    });
  });
  return matches
    .sort((a, b) => a.make.localeCompare(b.make) || a.model.localeCompare(b.model) || b.fromYear - a.fromYear)
    .slice(0, Math.max(1, Math.min(limit, 100)));
}

/** A make as a file name, e.g. `land-rover`: its mark is `design/car-logos/{slug}.svg`. */
export function makeSlug(make: string): string {
  return slug(make);
}

/** Makes in the catalogue, alphabetical. */
export function vehicleMakes(vehicles: readonly Vehicle[]): string[] {
  return [...new Set(vehicles.map((v) => v.make))].sort((a, b) => a.localeCompare(b));
}
