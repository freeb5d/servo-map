import { haversineKm } from "@/lib/utils";

/** The visible map rectangle as Mapbox reports it: corners as [lng, lat]. Australia only, so no antimeridian. */
export interface ViewBounds {
  ne: [number, number];
  sw: [number, number];
}

export interface GeoPoint {
  lat: number;
  lng: number;
}

/** Whether a point lies inside the rectangle, edges included. */
export function boundsContain(bounds: ViewBounds, lat: number, lng: number): boolean {
  return lat >= bounds.sw[1] && lat <= bounds.ne[1] && lng >= bounds.sw[0] && lng <= bounds.ne[0];
}

/** The middle of the rectangle. */
export function boundsCenter(bounds: ViewBounds): GeoPoint {
  return { lat: (bounds.ne[1] + bounds.sw[1]) / 2, lng: (bounds.ne[0] + bounds.sw[0]) / 2 };
}

/**
 * Whether a fetch circle covers the whole rectangle. At map scales the rectangle's farthest
 * points from any centre are its corners, so checking the four corners is enough.
 */
export function circleCovers(center: GeoPoint, radiusKm: number, bounds: ViewBounds): boolean {
  const corners: [number, number][] = [bounds.ne, bounds.sw, [bounds.ne[0], bounds.sw[1]], [bounds.sw[0], bounds.ne[1]]];
  return corners.every(([lng, lat]) => haversineKm(center.lat, center.lng, lat, lng) <= radiusKm);
}
