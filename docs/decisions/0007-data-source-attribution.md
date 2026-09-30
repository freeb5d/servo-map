# 0007 — Data-source attribution

- Date: 2026-09-30
- Status: **accepted**
- Owner: Henry Chen
- Evidence: the licence texts quoted in `packages/shared/src/data-sources.ts`

## Problem

QLD, SA and VIC access was applied for on 2026-09-30, and each licence prescribes a statement that must
appear with the data:

- **QLD** (Limited Use Licence 4.3): "Based on or contains data provided by the State of Queensland
  (Department of Energy and Climate) [year]", followed by no-warranty terms. Clause 4.4 also requires
  its data to be distinguishable from other sources.
- **SA** (Data Publisher Terms 3.1 to 3.3): "Based on or contains data provided by the State of South
  Australia (Office of Consumer and Business Services) 2021-2023. Copyright of the State of South
  Australia". Sources must be distinguished, and consumers must be able to complain to the State
  when a price is not current.
- **VIC** (Servo Saver terms): "© State of Victoria accessed via the Victorian Government Service
  Victoria Platform".

NSW FuelCheck and WA FuelWatch are CC BY 3.0 and need credit only. The facts were duplicated before
this decision:

- Web's About page and its station "via …" line each kept their own table.
- The About page still said "Pending integration" for TAS and ACT, and linked NT to a dead host.
- iOS showed no source at all.

## Options

- A. Statements on the About page only. Light, but SA and VIC ask for the statement wherever the data is
  redisplayed.
- B. Credit on every price ("via …"), and the prescribed statement wherever that state's prices
  appear. That means the station panel, and the footer of station, suburb and state pages, plus the
  About page.
- C. One combined legal block in a global footer. It lists every state's terms on pages showing
  none of their data, and fails "distinguish the sources".

## Choice

**B**, with the facts owned by one table:

- `@servo-map/shared` `DATA_SOURCES` holds, per state, the name, url, About-page note, statement
  (`{year}` filled at render) and report link.
- Web reads the table directly. iOS reads the generated `ServoMapDataSources.swift`, and a drift
  test keeps that file in step.
- A statement renders only where that state's prices are shown. QLD, SA and VIC text therefore
  appears once their data is live, with no code change.
- SA's statement keeps its prescribed "2021-2023" as written.
