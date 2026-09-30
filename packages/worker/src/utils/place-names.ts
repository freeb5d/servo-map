import type { AustralianState } from "@servo-map/shared";

// The ingest script loads adapters under tsx as CommonJS, and @servo-map/shared only exports
// an ESM entry, so this module may import types from it but no values. The Record type makes
// the compiler fail here whenever a state is added to or removed from AUSTRALIAN_STATES.
const STATE_CODES: Record<Uppercase<AustralianState>, true> = {
  NSW: true,
  VIC: true,
  QLD: true,
  WA: true,
  SA: true,
  TAS: true,
  ACT: true,
  NT: true,
};

// Upstream feeds mix "CROYDON" and "Dulwich Hill". Only all-caps text is recased, so names
// that already carry deliberate casing ("McMahons Point", "TEMCO Petroleum") stay as sent.
const KEEP_UPPER = new Set<string>([
  ...Object.keys(STATE_CODES),
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
  return part
    .toLowerCase()
    .replace(/(^|')([a-z])/g, (_, sep: string, ch: string) => sep + ch.toUpperCase());
}

function recaseWord(word: string): string {
  return word.split("-").map(recasePart).join("-");
}

/** Title-cases an all-caps place, street or station name; leaves mixed-case text alone. */
export function titleCasePlace(text: string): string {
  if (text !== text.toUpperCase()) return text;
  return text.replace(/[A-Za-z0-9'-]+/g, recaseWord);
}
