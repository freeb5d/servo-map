/** `priceCheapSoft` → `price-cheap-soft`; digits stay attached (`ink2` → `ink-2`). */
export function kebab(name: string): string {
  return name.replace(/([a-z])([A-Z0-9])/g, "$1-$2").toLowerCase();
}
