import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { BODY_TYPES, type Vehicle } from "../vehicles";
import { vehicleImagePath, withImage } from "../vehicle-images";
import { emitVehicleImagesSwift } from "../emit-vehicle-images-swift";

const cx5: Vehicle = {
  id: "mazda-cx-5-2017",
  make: "Mazda",
  model: "CX-5",
  fromYear: 2017,
  body: "suv",
  fuel: "U91",
  tankLitres: 56,
  source: "https://example.com/cx5",
};

describe("vehicleImagePath", () => {
  it("uses the generation's own render when there is one", () => {
    expect(vehicleImagePath(cx5, new Set(["mazda-cx-5-2017"]))).toBe("/cars/mazda-cx-5-2017.jpg");
  });

  it("falls back to the stand-in for the body type", () => {
    expect(vehicleImagePath(cx5, new Set())).toBe("/cars/generic-suv.jpg");
    expect(vehicleImagePath(cx5, new Set(["mazda-cx-5-2015"]))).toBe("/cars/generic-suv.jpg");
  });

  it("has a stand-in for every body type", () => {
    for (const body of BODY_TYPES) expect(vehicleImagePath({ body }, new Set())).toBe(`/cars/generic-${body}.jpg`);
  });

  it("pictures a hand-entered car with no body type as a hatch", () => {
    expect(vehicleImagePath({}, new Set())).toBe("/cars/generic-hatch.jpg");
    expect(vehicleImagePath({ id: undefined, body: "ute" }, new Set())).toBe("/cars/generic-ute.jpg");
  });

  it("adds the path to a catalogue generation without changing it", () => {
    const listed = withImage(cx5, new Set());
    expect(listed).toEqual({ ...cx5, image: "/cars/generic-suv.jpg" });
    expect(cx5).not.toHaveProperty("image");
  });
});

describe("emitVehicleImagesSwift", () => {
  it("matches the committed Swift file (run `pnpm --filter @servo-map/shared generate`)", () => {
    const committed = readFileSync(
      fileURLToPath(new URL("../../generated/swift/ServoMapVehicleImages.swift", import.meta.url)),
      "utf8",
    );
    expect(committed).toBe(emitVehicleImagesSwift());
  });

  it("lists the rendered generations and names the same paths", () => {
    const swift = emitVehicleImagesSwift(new Set(["toyota-rav4-2019", "mazda-cx-5-2017"]));
    expect(swift).toContain('static let rendered: Set<String> = ["mazda-cx-5-2017", "toyota-rav4-2019"]');
    expect(swift).toContain('"generic-\\(body ?? "hatch")"');
    expect(swift).toContain('return "/cars/\\(name).jpg"');
  });
});
