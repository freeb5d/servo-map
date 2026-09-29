"use client";

import { useCallback, useRef, useState } from "react";
import { haversineKm } from "@/lib/utils";

// Sydney CBD: the cold-start view, not the viewer's position.
export const DEFAULT_CENTER = { lat: -33.8688, lng: 151.2093 };
const DEFAULT_RADIUS_KM = 20;
const DEFAULT_ZOOM = 12;
// A pan shorter than this at an unchanged zoom does not warrant another request.
const REFETCH_MIN_MOVE_KM = 1;

export interface MapBounds {
  ne: [number, number];
  sw: [number, number];
  zoom: number;
}

/**
 * The query area that follows the map. The gate keeps small drags from refetching, and a
 * user-driven move calls `onUserMoved` so a searched suburb gives way to browsing.
 */
export function useMapViewport(onUserMoved: () => void) {
  const [center, setCenter] = useState(DEFAULT_CENTER);
  const [radius, setRadius] = useState(DEFAULT_RADIUS_KM);
  // The view of the last request, for the gate above.
  const lastQuery = useRef({ ...DEFAULT_CENTER, zoom: DEFAULT_ZOOM });

  const handleMoveEnd = useCallback(
    (bounds: MapBounds) => {
      const lat = (bounds.ne[1] + bounds.sw[1]) / 2;
      const lng = (bounds.ne[0] + bounds.sw[0]) / 2;
      const last = lastQuery.current;
      const movedKm = haversineKm(last.lat, last.lng, lat, lng);
      const zoomChanged = Math.abs(bounds.zoom - last.zoom) >= 0.5;
      if (movedKm < REFETCH_MIN_MOVE_KM && !zoomChanged) return;

      // Half the diagonal is a rough radius in km.
      const dlat = bounds.ne[1] - bounds.sw[1];
      const dlng = bounds.ne[0] - bounds.sw[0];
      const approxKm = (Math.sqrt(dlat * dlat + dlng * dlng) * 111) / 2;

      lastQuery.current = { lat, lng, zoom: bounds.zoom };
      onUserMoved();
      setCenter({ lat, lng });
      setRadius(Math.round(Math.max(5, Math.min(approxKm, 200))));
    },
    [onUserMoved],
  );

  // Recording the view too stops the flyTo that follows from counting as a user move.
  const recenter = useCallback((coords: { lat: number; lng: number }) => {
    setCenter(coords);
    setRadius(DEFAULT_RADIUS_KM);
    lastQuery.current = { ...coords, zoom: 13 };
  }, []);

  return { center, radius, handleMoveEnd, recenter };
}
