import { describe, expect, it } from "vitest";
import { brandLogoImage } from "./logoImage";

describe("brandLogoImage", () => {
  it("asks the image optimiser for a small copy of the logo", () => {
    expect(brandLogoImage("7-eleven")).toBe("/_next/image?url=%2Fbrand-logos%2F7-eleven.png&w=64&q=75");
  });

  it("is null for a family without a logo", () => {
    expect(brandLogoImage("speedway")).toBeNull();
  });
});
