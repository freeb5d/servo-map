import { RENDERED_VEHICLE_IDS } from "./generated/car-renders";
import type { BodyType, Vehicle } from "./vehicles";

/** Folder on the website (`packages/web/public/cars`) that serves every car picture. */
export const CAR_IMAGE_DIR = "/cars";

/** Name prefix of the unbranded stand-in picture drawn for each body type. */
export const GENERIC_CAR_IMAGE_PREFIX = "generic-";

/** The body type pictured when a hand-entered car has none. */
export const DEFAULT_CAR_IMAGE_BODY: BodyType = "hatch";

/** A catalogue generation as the API serves it: with the site path of its picture (decision 0008). */
export interface VehicleWithImage extends Vehicle {
  /** Site-relative path, e.g. `/cars/generic-suv.jpg`; resolve it against the website origin. */
  image: string;
}

/**
 * Site path of a car's picture: the generation's own render when there is one, otherwise the
 * unbranded stand-in for its body type (the hatch when a hand-entered car has no body type).
 * The one owner of this rule: the Worker serves it and iOS compiles the generated Swift copy.
 */
export function vehicleImagePath(
  v: { id?: string; body?: BodyType },
  rendered: ReadonlySet<string> = RENDERED_VEHICLE_IDS,
): string {
  const name = v.id !== undefined && rendered.has(v.id) ? v.id : `${GENERIC_CAR_IMAGE_PREFIX}${v.body ?? DEFAULT_CAR_IMAGE_BODY}`;
  return `${CAR_IMAGE_DIR}/${name}.jpg`;
}

/** Adds the picture path the API serves with every catalogue generation. */
export function withImage(v: Vehicle, rendered: ReadonlySet<string> = RENDERED_VEHICLE_IDS): VehicleWithImage {
  return { ...v, image: vehicleImagePath(v, rendered) };
}
