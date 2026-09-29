import { AUSTRALIAN_STATES, type Station } from "@servo-map/shared";

// Upstream feeds mix "CROYDON" and "Dulwich Hill". Only all-caps text is recased, so names
// that already carry deliberate casing ("McMahons Point", "TEMCO Petroleum") stay as sent.
const KEEP_UPPER = new Set<string>([
  ...AUSTRALIAN_STATES.map((s) => s.toUpperCase()),
  "BP",
  "EG",
  "IOR",
  "OMG",
  "UGO",
  "PO",
]);

function recasePart(part: string): string {
  // Numbers and unit suffixes ("221", "97A") and known acronyms keep their capitals.
  if (KEEP_UPPER.has(part) || /\d/.test(part)) return part;
  // Capitalise after an apostrophe too ("O'CONNELL" → "O'Connell").
  return part.toLowerCase().replace(/(^|')([a-z])/g, (_, sep: string, ch: string) => sep + ch.toUpperCase());
}

function recaseWord(word: string): string {
  return word.split("-").map(recasePart).join("-");
}

/** Title-cases an all-caps place, street or station name; leaves mixed-case text alone. */
export function titleCasePlace(text: string): string {
  if (text !== text.toUpperCase()) return text;
  return text.replace(/[A-Za-z0-9'-]+/g, recaseWord);
}

/** Display copy of a station with consistently cased name, address and suburb. */
export function normalizeStation<T extends Station>(station: T): T {
  return {
    ...station,
    name: titleCasePlace(station.name),
    address: titleCasePlace(station.address),
    suburb: titleCasePlace(station.suburb),
  };
}

/** Full address line; skips the suburb and postcode when the feed already put them in the address. */
export function formatAddress(station: Pick<Station, "address" | "suburb" | "state" | "postcode">): string {
  if (station.address.toLowerCase().includes(station.suburb.toLowerCase())) return station.address;
  return `${station.address}, ${station.suburb} ${station.state.toUpperCase()} ${station.postcode}`;
}
