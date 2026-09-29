"use client";

import {
  useRef,
  useCallback,
  useEffect,
  useState,
  useMemo,
  useSyncExternalStore,
} from "react";
import MapGL, {
  Marker,
  Source,
  Layer,
  NavigationControl,
  type MapRef,
  type ViewStateChangeEvent,
  type MapLayerMouseEvent,
  type GeoJSONSource,
} from "react-map-gl";
import type { StationWithDistance, FuelType } from "@servo-map/shared";
import { useTheme } from "@/providers/ThemeProvider";
import { usePriceRange } from "@/providers/PriceRangeProvider";
import { MapLegend } from "./MapLegend";
import {
  SOURCE_ID,
  CLUSTER_LAYER_ID,
  CLUSTER_LABEL_LAYER_ID,
  CLUSTER_PROPERTIES,
  POINT_LAYER_ID,
  ACTIVE_LAYER_ID,
  clusterLayer,
  clusterCountLayer,
  clusterLabelLayer,
  pointLayer,
  activeLayer,
  mapStyleUrl,
  applyStyleOverrides,
} from "./mapLayers";
import { buildStationCollection } from "./mapData";
import { registerTagImages } from "./tagImages";
import "mapbox-gl/dist/mapbox-gl.css";

const MAPBOX_TOKEN = process.env.NEXT_PUBLIC_MAPBOX_TOKEN || "";

const noopSubscribe = () => () => {};

// 澳洲中心
const INITIAL_VIEW = {
  latitude: -33.8688,
  longitude: 151.2093,
  zoom: 12,
};

interface MapViewProps {
  stations: StationWithDistance[];
  selectedFuel: FuelType;
  activeStationId: string | null;
  userLocation: { lat: number; lng: number } | null;
  searchQuery: string;
  onStationClick: (station: StationWithDistance) => void;
  onMoveEnd?: (bounds: {
    ne: [number, number];
    sw: [number, number];
    zoom: number;
  }) => void;
}

export function MapView({
  stations,
  selectedFuel,
  activeStationId,
  userLocation,
  searchQuery,
  onStationClick,
  onMoveEnd,
}: MapViewProps) {
  const mapRef = useRef<MapRef>(null);
  const { theme } = useTheme();
  const range = usePriceRange();
  const [ready, setReady] = useState(false);
  // Hydration renders the server's default theme; creating the map only after it avoids
  // loading one style and immediately swapping to the viewer's stored theme.
  const hydrated = useSyncExternalStore(noopSubscribe, () => true, () => false);
  // A theme switch can make Mapbox rebuild the style from scratch, which drops our
  // source and layers; bumping this key on every `style.load` re-adds them.
  const [styleGen, setStyleGen] = useState(0);
  const themeRef = useRef(theme);
  useEffect(() => {
    themeRef.current = theme;
  }, [theme]);
  // Mapbox also drops style images on a rebuild, so the tag images go back in before the layers.
  const handleStyleLoad = useCallback(() => {
    const map = mapRef.current?.getMap();
    if (map) registerTagImages(map, themeRef.current);
    setStyleGen((g) => g + 1);
  }, []);

  const mapStyle = mapStyleUrl(theme);

  const data = useMemo(
    () => buildStationCollection(stations, selectedFuel, range),
    [stations, selectedFuel, range],
  );

  // id → station 映射，点击 unclustered point 时回查原始站点对象
  const stationById = useMemo(() => {
    const m = new globalThis.Map<string, StationWithDistance>();
    for (const s of stations) m.set(s.id, s);
    return m;
  }, [stations]);

  // 用户定位后飞过去
  useEffect(() => {
    if (userLocation && mapRef.current) {
      mapRef.current.flyTo({
        center: [userLocation.lng, userLocation.lat],
        zoom: 13,
        duration: 1500,
      });
    }
  }, [userLocation]);

  // A station picked in the ledger may be off screen; bring it into view without
  // zooming out. Programmatic moves carry no originalEvent, so they never refetch.
  useEffect(() => {
    const map = mapRef.current;
    const station = activeStationId ? stationById.get(activeStationId) : undefined;
    if (!map || !station) return;
    if (map.getBounds()?.contains([station.lng, station.lat])) return;
    map.easeTo({
      center: [station.lng, station.lat],
      zoom: Math.max(map.getZoom(), 13),
      duration: 600,
    });
  }, [activeStationId, stationById]);

  // 搜索结果返回后，将地图视野调整到结果范围
  useEffect(() => {
    if (!searchQuery || stations.length === 0 || !mapRef.current) return;

    if (stations.length === 1) {
      mapRef.current.flyTo({
        center: [stations[0].lng, stations[0].lat],
        zoom: 14,
        duration: 1200,
      });
    } else {
      // 计算所有搜索结果的边界
      let minLat = Infinity, maxLat = -Infinity;
      let minLng = Infinity, maxLng = -Infinity;
      for (const s of stations) {
        if (s.lat < minLat) minLat = s.lat;
        if (s.lat > maxLat) maxLat = s.lat;
        if (s.lng < minLng) minLng = s.lng;
        if (s.lng > maxLng) maxLng = s.lng;
      }
      mapRef.current.fitBounds(
        [[minLng, minLat], [maxLng, maxLat]],
        { padding: 60, maxZoom: 15, duration: 1200 },
      );
    }
  }, [searchQuery, stations]);

  // 只上报用户手动触发的移动。程序化移动(flyTo/fitBounds)没有 originalEvent，
  // 忽略它们可以避免搜索后的自动飞行把 searchSuburb 清空。
  const handleMoveEnd = useCallback(
    (e: ViewStateChangeEvent) => {
      if (!mapRef.current || !onMoveEnd) return;
      if (!e.originalEvent) return;
      const bounds = mapRef.current.getBounds();
      if (bounds) {
        onMoveEnd({
          ne: [bounds.getNorthEast().lng, bounds.getNorthEast().lat],
          sw: [bounds.getSouthWest().lng, bounds.getSouthWest().lat],
          zoom: mapRef.current.getZoom(),
        });
      }
    },
    [onMoveEnd],
  );

  // 点击：聚类点 → 展开缩放；单站点 → 选中并打开详情
  const handleClick = useCallback(
    (e: MapLayerMouseEvent) => {
      const map = mapRef.current;
      const feature = e.features?.[0];
      if (!map || !feature) return;

      // 聚类点：properties.cluster 为 true，按 getClusterExpansionZoom 缩放进去
      if (feature.properties?.cluster) {
        const clusterId = feature.properties.cluster_id as number;
        const source = map.getSource<GeoJSONSource>(SOURCE_ID);
        if (!source) return;
        source.getClusterExpansionZoom(clusterId, (err, zoom) => {
          if (err || zoom == null) return;
          const [lng, lat] = (feature.geometry as GeoJSON.Point).coordinates;
          map.easeTo({ center: [lng, lat], zoom, duration: 500 });
        });
        return;
      }

      // 单站点：回查原始站点对象后交给上层（选中 + 列表高亮 + 详情）
      const id = feature.properties?.id as string | undefined;
      if (!id) return;
      const station = stationById.get(id);
      if (station) onStationClick(station);
    },
    [onStationClick, stationById],
  );

  // 悬停聚类点 / 站点时显示手型光标
  const handleMouseEnter = useCallback(() => {
    const map = mapRef.current;
    if (map) map.getCanvas().style.cursor = "pointer";
  }, []);
  const handleMouseLeave = useCallback(() => {
    const map = mapRef.current;
    if (map) map.getCanvas().style.cursor = "";
  }, []);

  return (
    <div className="absolute inset-0 bg-bg">
      {hydrated && (
        <MapGL
          ref={mapRef}
          mapboxAccessToken={MAPBOX_TOKEN}
          initialViewState={INITIAL_VIEW}
          mapStyle={mapStyle}
          onMoveEnd={handleMoveEnd}
          onLoad={(e) => {
            applyStyleOverrides(e.target, theme);
            registerTagImages(e.target, theme);
            // reuseMaps keeps the map across remounts, so drop any earlier listener first.
            e.target.off("style.load", handleStyleLoad);
            e.target.on("style.load", handleStyleLoad);
            setReady(true);
          }}
          onStyleData={() => {
            const map = mapRef.current?.getMap();
            if (map) applyStyleOverrides(map, theme);
          }}
          onClick={handleClick}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          interactiveLayerIds={[CLUSTER_LAYER_ID, CLUSTER_LABEL_LAYER_ID, POINT_LAYER_ID, ACTIVE_LAYER_ID]}
          attributionControl={false}
          reuseMaps
        >
          <NavigationControl position="bottom-right" showCompass={false} />

          {/* 用户位置标记：静态圆点 + 淡色外圈，不做动画（静） */}
          {userLocation && (
            <Marker latitude={userLocation.lat} longitude={userLocation.lng}>
              <div className="w-3 h-3 rounded-full bg-accent border-2 border-surface outline outline-[6px] outline-accent/15" />
            </Marker>
          )}

          {/* 加油站聚类图层 — Mapbox 原生 GeoJSON clustering，取代逐个 DOM Marker */}
          {ready && (
            <Source
              key={styleGen}
              id={SOURCE_ID}
              type="geojson"
              data={data}
              cluster
              clusterMaxZoom={13}
              clusterRadius={56}
              // Pairs of stations read better as two tags than as a "2" disc.
              clusterMinPoints={3}
              clusterProperties={CLUSTER_PROPERTIES}
            >
              <Layer {...clusterLayer(theme)} />
              <Layer {...clusterCountLayer(theme)} />
              <Layer {...clusterLabelLayer(theme)} />
              <Layer {...pointLayer(theme, activeStationId)} />
              <Layer {...activeLayer(theme, activeStationId)} />
            </Source>
          )}
        </MapGL>
      )}

      <MapLegend />
    </div>
  );
}
