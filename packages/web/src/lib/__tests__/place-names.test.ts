import { describe, expect, it } from "vitest";
import { formatAddress, normalizeStation, titleCasePlace } from "../place-names";

describe("titleCasePlace", () => {
  it.each([
    ["CROYDON", "Croydon"],
    ["BUDGET PETROL ASHFIELD", "Budget Petrol Ashfield"],
    ["6 DOYLE RD, REVESBY NSW 2212", "6 Doyle Rd, Revesby NSW 2212"],
    ["97A HUME HWY, GREENACRE NSW 2190", "97A Hume Hwy, Greenacre NSW 2190"],
    ["221-229 ELIZABETH ST", "221-229 Elizabeth St"],
    ["O'CONNELL", "O'Connell"],
    ["7-ELEVEN YAGOONA", "7-Eleven Yagoona"],
    ["BP CAMPERDOWN", "BP Camperdown"],
    ["CASTLE-HILL", "Castle-Hill"],
  ])("recases %s", (input, expected) => {
    expect(titleCasePlace(input)).toBe(expected);
  });

  it("leaves mixed-case names untouched", () => {
    expect(titleCasePlace("McMahons Point")).toBe("McMahons Point");
    expect(titleCasePlace("TEMCO Petroleum")).toBe("TEMCO Petroleum");
    expect(titleCasePlace("")).toBe("");
  });
});

describe("formatAddress", () => {
  const base = { suburb: "Revesby", state: "nsw" as const, postcode: "2212" };

  it("does not repeat a suburb the address already contains", () => {
    expect(formatAddress({ ...base, address: "6 Doyle Rd, Revesby NSW 2212" })).toBe("6 Doyle Rd, Revesby NSW 2212");
  });

  it("appends suburb, state and postcode when missing", () => {
    expect(formatAddress({ ...base, address: "6 Doyle Rd" })).toBe("6 Doyle Rd, Revesby NSW 2212");
  });
});

describe("normalizeStation", () => {
  it("recases name, address and suburb and keeps everything else", () => {
    const s = normalizeStation({
      id: "nsw-1",
      name: "METRO REVESBY",
      brand: "Metro Fuel",
      address: "6 DOYLE RD, REVESBY NSW 2212",
      suburb: "REVESBY",
      state: "nsw",
      postcode: "2212",
      lat: -33.9,
      lng: 151.0,
      prices: [],
    });
    expect([s.name, s.address, s.suburb, s.brand]).toEqual(["Metro Revesby", "6 Doyle Rd, Revesby NSW 2212", "Revesby", "Metro Fuel"]);
  });
});
