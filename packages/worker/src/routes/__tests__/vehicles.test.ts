import { describe, it, expect } from "vitest";
import { parseVehicles, type ApiResponse, type Vehicle } from "@servo-map/shared";
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
    const body = (await res.json()) as ApiResponse<Vehicle[]>;
    expect(body.data.map((v) => v.model)).toEqual(["Corolla", "HiLux"]);
    expect(body.data[0]).toMatchObject({ tankLitres: 50, fuel: "U91", body: "hatch" });
    expect(res.headers.get("Cache-Control")).toContain("s-maxage=86400");
  });

  it("returns an empty list when nothing matches", async () => {
    const body = (await (await route.request("/?q=tesla")).json()) as ApiResponse<Vehicle[]>;
    expect(body.data).toEqual([]);
  });

  it("clamps the limit", async () => {
    const body = (await (await route.request("/?limit=1")).json()) as ApiResponse<Vehicle[]>;
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
