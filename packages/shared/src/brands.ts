/** How a brand family is grouped in filters and rankings. */
export type BrandGroup = "major" | "value" | "members" | "independent";

/**
 * A brand's mark: a filled tile in the brand's colour with its monogram. Drawn by ServoMap in one
 * style for every brand; never a copy of the brand's logo. `foreground` on `background` must
 * reach WCAG AA (4.5:1), which the tests check. `stripe` is an optional second brand colour.
 */
export interface BrandMark {
  background: string;
  foreground: string;
  stripe?: string;
}

/** A family of raw upstream brand names shown as one brand. */
export interface BrandFamily {
  /** Stable kebab-case id, used in URLs (`?brands=metro,costco`). */
  id: string;
  /** Display name. */
  name: string;
  /** Short monogram printed on the brand mark; never a logo. */
  seal: string;
  group: BrandGroup;
  /** Colours of the brand mark (decision 0003). */
  mark: BrandMark;
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
  mark: { background: "#5A5750", foreground: "#FFFFFF" },
  names: ["independent"],
};

/** Brand families in display order. Upstream names are messy, so every consumer goes through this table. */
export const BRAND_FAMILIES: readonly BrandFamily[] = [
  { id: "ampol", name: "Ampol", seal: "AMP", group: "major", mark: { background: "#0B2D72", foreground: "#FFFFFF", stripe: "#E4002B" }, names: [], contains: ["ampol"] },
  { id: "bp", name: "BP", seal: "BP", group: "major", mark: { background: "#007A33", foreground: "#FFFFFF", stripe: "#FFD100" }, names: ["bp"] },
  { id: "shell", name: "Shell", seal: "SHL", group: "major", mark: { background: "#FFD200", foreground: "#A30D14", stripe: "#DD1D21" }, names: ["reddy express", "coles express"], contains: ["shell"] },
  { id: "7-eleven", name: "7-Eleven", seal: "7E", group: "major", mark: { background: "#006B4F", foreground: "#FFFFFF", stripe: "#F47B20" }, names: ["7-eleven", "7 eleven"] },
  { id: "caltex", name: "Caltex", seal: "CTX", group: "major", mark: { background: "#C8102E", foreground: "#FFFFFF", stripe: "#0055A5" }, names: [], contains: ["caltex"] },
  { id: "mobil", name: "Mobil", seal: "MOB", group: "major", mark: { background: "#1E4494", foreground: "#FFFFFF", stripe: "#E31B23" }, names: [], contains: ["mobil"] },
  { id: "metro", name: "Metro", seal: "MET", group: "value", mark: { background: "#003DA5", foreground: "#FFFFFF", stripe: "#FFC72C" }, names: [], contains: ["metro"] },
  { id: "united", name: "United", seal: "UTD", group: "value", mark: { background: "#B5122D", foreground: "#FFFFFF", stripe: "#00338D" }, names: ["united"] },
  { id: "speedway", name: "Speedway", seal: "SPD", group: "value", mark: { background: "#1F1F1F", foreground: "#FFFFFF", stripe: "#E4002B" }, names: ["speedway"] },
  { id: "liberty", name: "Liberty", seal: "LIB", group: "value", mark: { background: "#00539B", foreground: "#FFFFFF", stripe: "#E03C31" }, names: ["liberty"] },
  { id: "puma", name: "Puma", seal: "PUM", group: "value", mark: { background: "#B71C24", foreground: "#FFFFFF" }, names: ["puma"] },
  { id: "astron", name: "Astron", seal: "AST", group: "value", mark: { background: "#F37021", foreground: "#1F1F1F" }, names: ["astron"] },
  { id: "u-go", name: "U-Go", seal: "UGO", group: "value", mark: { background: "#7AC143", foreground: "#1F1F1F" }, names: ["u-go", "ugo"] },
  { id: "costco", name: "Costco", seal: "CST", group: "members", mark: { background: "#005DAA", foreground: "#FFFFFF", stripe: "#E31837" }, names: ["costco"] },
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
