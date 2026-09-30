import { describe, expect, it } from "vitest";
import { parseVehicles, searchVehicles, vehicleMakes } from "../vehicles";

const HEADER = "make,model,from_year,to_year,body,fuel,tank_litres,source";
const CSV = [
  HEADER,
  "Toyota,Corolla,2019,,hatch,U91,50,https://www.toyota.com.au/corolla",
  "Toyota,Corolla,2013,2018,hatch,U91,50,https://example.com/a",
  "Toyota,HiLux,2015,,ute,Diesel,80,https://example.com/b",
  'Mazda,"CX-5",2017,,suv,U91,58,https://example.com/c',
].join("\n");

describe("parseVehicles", () => {
  it("reads rows into typed vehicles with stable ids", () => {
    const v = parseVehicles(CSV);
    expect(v).toHaveLength(4);
    expect(v[0]).toMatchObject({ id: "toyota-corolla-2019", make: "Toyota", model: "Corolla", fromYear: 2019, toYear: undefined, body: "hatch", fuel: "U91", tankLitres: 50 });
    expect(v[1].toYear).toBe(2018);
    expect(v[3].model).toBe("CX-5");
  });

  it.each([
    ["bad body", "Toyota,Corolla,2019,,coupe,U91,50,https://x.com"],
    ["bad fuel", "Toyota,Corolla,2019,,hatch,LPG,50,https://x.com"],
    ["bad tank", "Toyota,Corolla,2019,,hatch,U91,5,https://x.com"],
    ["years reversed", "Toyota,Corolla,2019,2015,hatch,U91,50,https://x.com"],
    ["no source", "Toyota,Corolla,2019,,hatch,U91,50,manual"],
  ])("rejects a row with %s", (_name, row) => {
    expect(() => parseVehicles(`${HEADER}\n${row}`)).toThrow(/row 2/);
  });

  it("rejects a wrong header", () => {
    expect(() => parseVehicles("make,model\nToyota,Corolla")).toThrow(/header/);
  });
});

describe("searchVehicles", () => {
  const vehicles = parseVehicles(CSV);

  it("matches every word against make and model", () => {
    expect(searchVehicles(vehicles, "toyota cor").map((v) => v.id)).toEqual(["toyota-corolla-2019", "toyota-corolla-2013"]);
    expect(searchVehicles(vehicles, "cx-5").map((v) => v.model)).toEqual(["CX-5"]);
  });

  it("treats a four-digit word as a model year", () => {
    expect(searchVehicles(vehicles, "corolla 2016").map((v) => v.id)).toEqual(["toyota-corolla-2013"]);
    expect(searchVehicles(vehicles, "hilux 2026").map((v) => v.id)).toEqual(["toyota-hilux-2015"]);
  });

  it("returns nothing for no match and caps the limit", () => {
    expect(searchVehicles(vehicles, "tesla")).toEqual([]);
    expect(searchVehicles(vehicles, "", 2)).toHaveLength(2);
  });

  it("lists makes alphabetically", () => {
    expect(vehicleMakes(vehicles)).toEqual(["Mazda", "Toyota"]);
  });
});
