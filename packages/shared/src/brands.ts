/** How a brand family is grouped in filters and rankings. */
export type BrandGroup = "major" | "value" | "members" | "independent";

/** A family of raw upstream brand names shown as one brand. */
export interface BrandFamily {
  /** Stable kebab-case id, used in URLs (`?brands=metro,costco`). */
  id: string;
  /** Display name. */
  name: string;
  /** Short monogram printed on the brand seal (判子); never a logo. */
  seal: string;
  group: BrandGroup;
  /** Lower-case raw names that belong to this family, matched exactly. */
  names: readonly string[];
  /** Lower-case fragments; a raw name containing one belongs here. */
  contains?: readonly string[];
}

export const BRAND_GROUP_LABELS: Record<BrandGroup, string> = {
  major: "Majors",
  value: "Value chains",
  members: "Members only",
  independent: "Independent",
};

/** Catch-all family for any raw name no other family claims. */
export const INDEPENDENT_BRAND: BrandFamily = {
  id: "independent",
  name: "Independent",
  seal: "IND",
  group: "independent",
  names: ["independent"],
};

/** Brand families in display order. Upstream names are messy, so every consumer goes through this table. */
export const BRAND_FAMILIES: readonly BrandFamily[] = [
  { id: "ampol", name: "Ampol", seal: "AMP", group: "major", names: [], contains: ["ampol"] },
  { id: "bp", name: "BP", seal: "BP", group: "major", names: ["bp"] },
  { id: "shell", name: "Shell", seal: "SHL", group: "major", names: ["reddy express", "coles express"], contains: ["shell"] },
  { id: "7-eleven", name: "7-Eleven", seal: "7E", group: "major", names: ["7-eleven", "7 eleven"] },
  { id: "caltex", name: "Caltex", seal: "CTX", group: "major", names: [], contains: ["caltex"] },
  { id: "mobil", name: "Mobil", seal: "MOB", group: "major", names: [], contains: ["mobil"] },
  { id: "metro", name: "Metro", seal: "MET", group: "value", names: [], contains: ["metro"] },
  { id: "united", name: "United", seal: "UTD", group: "value", names: ["united"] },
  { id: "speedway", name: "Speedway", seal: "SPD", group: "value", names: ["speedway"] },
  { id: "liberty", name: "Liberty", seal: "LIB", group: "value", names: ["liberty"] },
  { id: "puma", name: "Puma", seal: "PUM", group: "value", names: ["puma"] },
  { id: "astron", name: "Astron", seal: "AST", group: "value", names: ["astron"] },
  { id: "u-go", name: "U-Go", seal: "UGO", group: "value", names: ["u-go", "ugo"] },
  { id: "costco", name: "Costco", seal: "CST", group: "members", names: ["costco"] },
  INDEPENDENT_BRAND,
];

/** Resolves a raw upstream brand name to its family; unknown names fall back to Independent. */
export function brandFamily(raw: string): BrandFamily {
  const key = raw.trim().toLowerCase();
  for (const family of BRAND_FAMILIES) {
    if (family.names.includes(key)) return family;
  }
  for (const family of BRAND_FAMILIES) {
    if (family.contains?.some((fragment) => key.includes(fragment))) return family;
  }
  return INDEPENDENT_BRAND;
}

/** Looks up a family by its URL id. */
export function brandFamilyById(id: string): BrandFamily | undefined {
  return BRAND_FAMILIES.find((family) => family.id === id);
}
