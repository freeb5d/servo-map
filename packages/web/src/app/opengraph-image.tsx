import { ImageResponse } from "next/og";
import { color } from "@servo-map/design-tokens";
import { BrandMark } from "@/components/brand/BrandMark";
import { MARK_COLORS } from "@/components/brand/mark";

export const alt = "ServoMap — Australian Fuel Prices";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function Image() {
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
          {/* The generated mark carries its own colours; the page is paper, so the light set. */}
          <BrandMark size={72} {...MARK_COLORS.light} />
          <div style={{ display: "flex", fontSize: 36, color: color.ink.light, fontWeight: 700 }}>
            ServoMap
          </div>
        </div>
        <div
          style={{
            display: "flex",
            fontSize: 84,
            fontWeight: 500,
            marginTop: 24,
            lineHeight: 1.05,
          }}
        >
          Australian Fuel Prices
        </div>
        <div style={{ display: "flex", fontSize: 36, color: color.ink3.light, marginTop: 24 }}>
          Find the cheapest petrol &amp; diesel near you
        </div>
      </div>
    ),
    { ...size },
  );
}
