import { describe, expect, it } from "vitest";
import { formatAddress } from "../place-names";

describe("formatAddress", () => {
  const base = { suburb: "Revesby", state: "nsw" as const, postcode: "2212" };

  it("does not repeat a suburb the address already contains", () => {
    expect(formatAddress({ ...base, address: "6 Doyle Rd, Revesby NSW 2212" })).toBe("6 Doyle Rd, Revesby NSW 2212");
  });

  it("appends suburb, state and postcode when missing", () => {
    expect(formatAddress({ ...base, address: "6 Doyle Rd" })).toBe("6 Doyle Rd, Revesby NSW 2212");
  });
});
