import { describe, expect, it } from "vitest";
import { boundsCenter, boundsContain, circleCovers, type ViewBounds } from "./viewArea";

// About 10 km across, centred on Sydney CBD.
const VIEW: ViewBounds = { ne: [151.26, -33.84], sw: [151.16, -33.9] };

describe("boundsContain", () => {
  it("includes points inside and on the edge", () => {
    expect(boundsContain(VIEW, -33.87, 151.21)).toBe(true);
    expect(boundsContain(VIEW, -33.84, 151.26)).toBe(true);
  });

  it("excludes points beyond any edge", () => {
    expect(boundsContain(VIEW, -33.83, 151.21)).toBe(false);
    expect(boundsContain(VIEW, -33.91, 151.21)).toBe(false);
    expect(boundsContain(VIEW, -33.87, 151.27)).toBe(false);
    expect(boundsContain(VIEW, -33.87, 151.15)).toBe(false);
  });
});

describe("boundsCenter", () => {
  it("is the middle of the rectangle", () => {
    const c = boundsCenter(VIEW);
    expect(c.lat).toBeCloseTo(-33.87);
    expect(c.lng).toBeCloseTo(151.21);
  });
});

describe("circleCovers", () => {
  const center = { lat: -33.87, lng: 151.21 };

  it("covers a view that sits inside the loaded circle", () => {
    expect(circleCovers(center, 20, VIEW)).toBe(true);
  });

  it("does not cover a view whose corners reach past the circle", () => {
    expect(circleCovers(center, 5, VIEW)).toBe(false);
  });

  it("does not cover a view panned out of the circle", () => {
    const west: ViewBounds = { ne: [150.96, -33.84], sw: [150.86, -33.9] };
    expect(circleCovers(center, 20, west)).toBe(false);
  });
});
