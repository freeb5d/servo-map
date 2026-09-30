import { ImageResponse } from "next/og";
import { color, markColor } from "@servo-map/design-tokens";
import { BrandMark } from "@/components/brand/BrandMark";

export const alt = "Cheapest fuel prices by suburb — ServoMap";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

interface Props {
  params: Promise<{ state: string; suburb: string }>;
}

export default async function Image({ params }: Props) {
  const { state, suburb } = await params;
  const suburbName = suburb
    .replace(/-/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

  return new ImageResponse(
    (
      <div
        style={{
          height: "100%",
          width: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "flex-start",
          justifyContent: "center",
          background: color.bg.light,
          padding: "80px",
          color: color.ink.light,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
          {/* The page is paper, so the mark takes its light colours. */}
          <BrandMark
            size={72}
            tile={markColor.tile.light}
            ink={markColor.ink.light}
            accent={markColor.accent.light}
          />
          <div style={{ display: "flex", fontSize: 32, color: color.ink.light, fontWeight: 700 }}>
            ServoMap
          </div>
        </div>
        <div
          style={{
            display: "flex",
            fontSize: 92,
            fontWeight: 500,
            marginTop: 20,
            lineHeight: 1.05,
          }}
        >
          {suburbName}
        </div>
        <div style={{ display: "flex", fontSize: 44, color: color.ink3.light, marginTop: 16 }}>
          {state.toUpperCase()} petrol and diesel prices
        </div>
      </div>
    ),
    { ...size },
  );
}
