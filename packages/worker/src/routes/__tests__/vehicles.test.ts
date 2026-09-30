import { describe, it, expect } from "vitest";
import { parseVehicles, type ApiResponse, type VehicleWithImage } from "@servo-map/shared";
import { createVehiclesRoute } from "../vehicles";

const catalogue = parseVehicles([
  "make,model,from_year,to_year,body,fuel,tank_litres,source",
  "Toyota,Corolla,2019,,hatch,U91,50,https://example.com/corolla",
  "Toyota,HiLux,2015,,ute,Diesel,80,https://example.com/hilux",
  "Mazda,CX-5,2017,,suv,U91,58,https://example.com/cx5",
].join("\n"));
const route = createVehiclesRoute(catalogue);

describe("GET /vehicles", () => {
  it("searches make and model", async () => {
    const res = await route.request("/?q=toyota");
    expect(res.status).toBe(200);
    const body = (await res.json()) as ApiResponse<VehicleWithImage[]>;
    expect(body.data.map((v) => v.model)).toEqual(["Corolla", "HiLux"]);
    expect(body.data[0]).toMatchObject({ tankLitres: 50, fuel: "U91", body: "hatch" });
    expect(res.headers.get("Cache-Control")).toContain("s-maxage=86400");
  });

  it("gives a generation without its own render the stand-in for its body", async () => {
    const unrendered = createVehiclesRoute(catalogue, new Set());
    const body = (await (await unrendered.request("/?q=toyota")).json()) as ApiResponse<VehicleWithImage[]>;
    expect(body.data.map((v) => v.image)).toEqual(["/cars/generic-hatch.jpg", "/cars/generic-ute.jpg"]);
  });

  it("uses a generation's own render when it has one", async () => {
    const rendered = createVehiclesRoute(catalogue, new Set(["mazda-cx-5-2017"]));
    const body = (await (await rendered.request("/?q=cx-5")).json()) as ApiResponse<VehicleWithImage[]>;
    expect(body.data[0].image).toBe("/cars/mazda-cx-5-2017.jpg");
  });

  it("returns an empty list when nothing matches", async () => {
    const body = (await (await route.request("/?q=tesla")).json()) as ApiResponse<VehicleWithImage[]>;
    expect(body.data).toEqual([]);
  });

  it("clamps the limit", async () => {
    const body = (await (await route.request("/?limit=1")).json()) as ApiResponse<VehicleWithImage[]>;
    expect(body.data).toHaveLength(1);
  });

  it("rejects an overlong query", async () => {
    const res = await route.request(`/?q=${"a".repeat(61)}`);
    expect(res.status).toBe(400);
    expect(((await res.json()) as { code: string }).code).toBe("INVALID_QUERY");
  });
});

describe("GET /vehicles/makes", () => {
  it("lists makes alphabetically", async () => {
    const body = (await (await route.request("/makes")).json()) as ApiResponse<string[]>;
    expect(body.data).toEqual(["Mazda", "Toyota"]);
  });
});
