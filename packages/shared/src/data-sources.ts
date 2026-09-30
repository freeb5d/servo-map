import type { AustralianState } from "./states";

/** Where a state's prices come from, and what its licence makes us show (decision 0007). */
export interface DataSource {
  /** The scheme's public name, credited on every price ("via NSW FuelCheck"). */
  name: string;
  /** The scheme's official site. */
  url: string;
  /** One line on how the scheme reports, for the About page. */
  note: string;
  /**
   * The statement the data licence prescribes wherever this state's prices appear, with
   * `{year}` standing for the current year; null where the licence asks only for credit.
   */
  attribution: string | null;
  /** Where people report a price that is wrong or stale, where the licence requires offering it. */
  reportUrl: string | null;
}

// The no-warranty terms Queensland's licence requires after its attribution line.
const QLD_NO_WARRANTY =
  "In consideration of the State permitting use of this data you acknowledge and agree that the State gives no warranty in relation to the data (including accuracy, reliability, completeness, currency or suitability) and accepts no liability (including without limitation, liability in negligence) for any loss, damage or costs (including consequential damage) relating to any use of the data. Data must not be used for direct marketing or be used in breach of the privacy laws.";

/**
 * Every state's source. Statements are quoted from each licence:
 * QLD Limited Use Licence clause 4.3; SA Data Publisher Terms v1 (Feb 2021) clauses 3.1 and 3.3;
 * VIC Servo Saver Open API Terms and Acceptable Use Policy. NSW FuelCheck and WA FuelWatch are
 * published under CC BY 3.0, which asks for credit only.
 */
export const DATA_SOURCES: Record<AustralianState, DataSource> = {
  nsw: {
    name: "NSW FuelCheck",
    url: "https://www.fuelcheck.nsw.gov.au/",
    note: "Mandatory real-time price reporting under the NSW Fuel Price Reporting scheme.",
    attribution: null,
    reportUrl: null,
  },
  act: {
    name: "NSW FuelCheck",
    url: "https://www.fuelcheck.nsw.gov.au/",
    note: "ACT service stations report their prices in real time through NSW FuelCheck.",
    attribution: null,
    reportUrl: null,
  },
  tas: {
    name: "FuelCheck TAS",
    url: "https://www.fuelcheck.tas.gov.au/",
    note: "Tasmania's mandatory price reporting, served through the NSW FuelCheck API.",
    attribution: null,
    reportUrl: null,
  },
  qld: {
    name: "Fuel Prices QLD",
    url: "https://www.fuelpricesqld.com.au/",
    note: "Real-time prices published under Queensland's mandatory fuel-price reporting scheme.",
    attribution: `Based on or contains data provided by the State of Queensland (Department of Energy and Climate) {year}. ${QLD_NO_WARRANTY}`,
    reportUrl: null,
  },
  sa: {
    name: "SA Fuel Pricing Information Scheme",
    url: "https://www.safuelpricinginformation.com.au/",
    note: "Retailers must report a price change within 30 minutes under South Australia's scheme.",
    attribution:
      "Based on or contains data provided by the State of South Australia (Office of Consumer and Business Services) 2021-2023. Copyright of the State of South Australia.",
    reportUrl: "https://www.cbs.sa.gov.au/fuel",
  },
  vic: {
    name: "Servo Saver",
    url: "https://service.vic.gov.au/find-services/transport-and-driving/servo-saver",
    note: "Service Victoria publishes prices 24 hours after retailers report them.",
    attribution: "© State of Victoria accessed via the Victorian Government Service Victoria Platform",
    reportUrl: null,
  },
  wa: {
    name: "FuelWatch",
    url: "https://www.fuelwatch.wa.gov.au/",
    note: "FuelWatch publishes each day's prices for the next day, so WA prices change once a day.",
    attribution: null,
    reportUrl: null,
  },
  nt: {
    name: "MyFuel NT",
    url: "https://myfuelnt.nt.gov.au/",
    note: "Mandatory real-time price reporting under the Northern Territory's MyFuel NT scheme.",
    attribution: null,
    reportUrl: null,
  },
};

/** The licence statement for a state's prices, dated `year`; null when only credit is required. */
export function dataAttribution(state: AustralianState, year: number): string | null {
  return DATA_SOURCES[state].attribution?.replace("{year}", String(year)) ?? null;
}
