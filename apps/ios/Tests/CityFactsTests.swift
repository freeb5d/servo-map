import Foundation
import Testing
@testable import ServoMap

/** The Cities and Timing facts, and decoding the worker's `/insights/cities` answer. */
struct CityFactsTests {
    private func city(_ id: String, _ state: String, avg: Double?, stations: Int = 10, share: Double? = 0.2,
                      histogram: CityHistogram? = nil, radius: Double = 20) -> CityInsight {
        CityInsight(id: id, name: id.prefix(1).uppercased() + id.dropFirst(), state: state, radiusKm: radius,
                    stationCount: stations, count: avg == nil ? 0 : stations, average: avg, min: avg.map { $0 - 10 },
                    max: avg.map { $0 + 10 }, median: avg, reportedWithin24hShare: share, histogram: histogram)
    }

    @Test func decodesTheWorkersAnswer() throws {
        let json = """
        {"status":"success","data":{"fuel":"U91","generated_at":"2026-09-30T06:00:00.000Z","cities":[
          {"id":"sydney","name":"Sydney","state":"nsw","radius_km":20,"station_count":336,"count":284,"average":236.7,
           "min":223.7,"max":253.9,"median":237.9,"reported_within_24h_share":0.199,
           "histogram":{"start":222,"width":2,"counts":[2,3,21]}},
          {"id":"hobart","name":"Hobart","state":"tas","radius_km":20,"station_count":0,"count":0,"average":null,
           "min":null,"max":null,"median":null,"reported_within_24h_share":null,"histogram":null}]}}
        """
        struct Envelope: Decodable { let data: CityInsights }
        let cities = try JSONDecoder().decode(Envelope.self, from: Data(json.utf8)).data.cities
        #expect(cities.count == 2)
        #expect(cities[0].stationCount == 336 && cities[0].count == 284 && cities[0].median == 237.9)
        #expect(cities[0].histogram?.bins.map(\.lower) == [222, 224, 226])
        #expect(cities[0].histogram?.total == 26)
        #expect(cities[1].average == nil && cities[1].histogram == nil)
    }

    @Test func rankedLeavesOutCitiesWithoutRecentPrices() {
        let ranked = CityFacts.ranked([city("sydney", "nsw", avg: 236.7), city("hobart", "tas", avg: nil),
                                       city("bunbury", "wa", avg: 232.2), city("launceston", "tas", avg: 246.6)])
        #expect(ranked.map(\.id) == ["bunbury", "sydney", "launceston"])
        #expect(CityFacts.cheapestFact(ranked) == "Bunbury is cheapest at 232.2¢ on average. Launceston is 14.4¢ dearer.")
        #expect(CityFacts.cheapestFact([ranked[0]]) == "Bunbury is cheapest at 232.2¢ on average.")
        #expect(CityFacts.cheapestFact([]) == nil)
    }

    @Test func radiusCaptionOnlyWhenEveryCityShares() {
        #expect(CityFacts.radiusCaption([city("a", "nsw", avg: 1), city("b", "wa", avg: 1)]) == "within 20 km of each centre")
        #expect(CityFacts.radiusCaption([city("a", "nsw", avg: 1), city("b", "wa", avg: 1, radius: 30)]) == "within each city's radius")
    }

    @Test func defaultCityHasTheMostStations() {
        let h = CityHistogram(start: 230, width: 2, counts: [1])
        let cities = [city("perth", "wa", avg: 239, stations: 281, histogram: h), city("sydney", "nsw", avg: 236.7, stations: 336, histogram: h),
                      city("hobart", "tas", avg: nil, stations: 400)]
        #expect(CityFacts.defaultCity(cities)?.id == "sydney")
    }

    @Test func histogramFactNamesTheTwoFullestBinsCheaperFirst() {
        let h = CityHistogram(start: 234, width: 2, counts: [5, 71, 69, 3])
        #expect(CityFacts.histogramFact(h) == "Two price points hold 140 stations: 236–238¢ and 238–240¢.")
        #expect(CityFacts.histogramFact(CityHistogram(start: 238, width: 2, counts: [0, 12])) == "Every station charges 240–242¢.")
        #expect(CityFacts.histogramFact(CityHistogram(start: 238, width: 2, counts: [0])) == nil)
    }

    @Test func reportingOrdersCitiesByShare() {
        let rows = CityFacts.byReporting([city("sydney", "nsw", avg: 1, share: 0.2), city("perth", "wa", avg: 1, share: 1),
                                          city("hobart", "tas", avg: nil, share: nil)])
        #expect(rows.map(\.id) == ["perth", "sydney"])
    }

    @Test func reportingFactNamesOnlyTheStatesShown() {
        #expect(CityFacts.reportingFact(states: ["nsw", "act", "wa", "tas"])
            == "WA stations post a price every day. In NSW, the ACT and Tasmania a station reports only when its price changes, so an old price is often still the current one.")
        #expect(CityFacts.reportingFact(states: ["wa"]) == "WA stations post a price every day.")
        #expect(CityFacts.reportingFact(states: ["nsw"]) == "In NSW a station reports only when its price changes, so an old price is often still the current one.")
        #expect(CityFacts.reportingFact(states: []) == nil)
    }

    @Test func collectingViewsOpenAfterTheirHistory() {
        #expect(CityFacts.opens(afterDays: CityFacts.cityHistoryDays) == "30 Oct")
        #expect(CityFacts.opens(afterDays: CityFacts.heatmapDays) == "28 Oct")
    }
}
