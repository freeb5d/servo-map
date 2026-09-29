import { ImageResponse } from "next/og";
import { BrandMark } from "@/components/brand/BrandMark";
import { MARK_COLORS } from "@/components/brand/mark";

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
          background: "#0C0B09",
          padding: "80px",
          color: "#FAF7F2",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
          <BrandMark size={72} {...MARK_COLORS.dark} />
          <div
            style={{
              display: "flex",
              fontSize: 32,
              color: MARK_COLORS.dark.ink,
              fontWeight: 700,
              letterSpacing: 2,
              textTransform: "uppercase",
            }}
          >
            ServoMap · Cheapest Fuel
          </div>
        </div>
        <div
          style={{
            display: "flex",
            fontSize: 92,
            fontWeight: 800,
            marginTop: 20,
            lineHeight: 1.05,
          }}
        >
          {suburbName}
        </div>
        <div style={{ display: "flex", fontSize: 44, color: "#B8B2A8", marginTop: 16 }}>
          {state.toUpperCase()} · petrol &amp; diesel prices
        </div>
      </div>
    ),
    { ...size },
  );
}
