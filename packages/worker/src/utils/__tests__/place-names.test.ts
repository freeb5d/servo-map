import { describe, expect, it } from "vitest";
import { AUSTRALIAN_STATES } from "@servo-map/shared";
import { titleCasePlace } from "../place-names";

describe("titleCasePlace", () => {
  it.each([
    ["CROYDON", "Croydon"],
    ["BUDGET PETROL ASHFIELD", "Budget Petrol Ashfield"],
    ["UMINA BEACH", "Umina Beach"],
  ])("recases all-caps %s", (input, expected) => {
    expect(titleCasePlace(input)).toBe(expected);
  });

  it.each([
    ["CASTLE-HILL", "Castle-Hill"],
    ["7-ELEVEN YAGOONA", "7-Eleven Yagoona"],
    ["O'CONNELL", "O'Connell"],
    ["D'AGUILAR-O'NEIL", "D'Aguilar-O'Neil"],
  ])("capitalises each part of hyphenated and apostrophised %s", (input, expected) => {
    expect(titleCasePlace(input)).toBe(expected);
  });

  it.each([
    ["97A HUME HWY, GREENACRE NSW 2190", "97A Hume Hwy, Greenacre NSW 2190"],
    ["221-229 ELIZABETH ST", "221-229 Elizabeth St"],
    ["UNIT 4B 12 MAIN RD", "Unit 4B 12 Main Rd"],
  ])("keeps unit and street numbers as sent in %s", (input, expected) => {
    expect(titleCasePlace(input)).toBe(expected);
  });

  it.each([
    ["6 DOYLE RD, REVESBY NSW 2212", "6 Doyle Rd, Revesby NSW 2212"],
    ["1 LONSDALE ST, BRADDON ACT 2612", "1 Lonsdale St, Braddon ACT 2612"],
    ["2 MACQUARIE ST, HOBART TAS 7000", "2 Macquarie St, Hobart TAS 7000"],
    ["BP CAMPERDOWN", "BP Camperdown"],
    ["EG AMPOL REVESBY", "EG Ampol Revesby"],
    ["PO BOX 12", "PO Box 12"],
  ])("keeps state codes and brand acronyms uppercase in %s", (input, expected) => {
    expect(titleCasePlace(input)).toBe(expected);
  });

  it.each(AUSTRALIAN_STATES.map((s) => s.toUpperCase()))("keeps state code %s uppercase", (code) => {
    expect(titleCasePlace(`1 MAIN ST, SOMEWHERE ${code} 2000`)).toBe(`1 Main St, Somewhere ${code} 2000`);
  });

  it.each(["McMahons Point", "TEMCO Petroleum", "Dulwich Hill", "6 Doyle Rd, Revesby NSW 2212", ""])(
    "leaves mixed-case or empty %j untouched",
    (input) => {
      expect(titleCasePlace(input)).toBe(input);
    },
  );
});
