import Foundation

/**
 * What a full tank costs near the map's centre today: at the cheapest, average and dearest
 * current price for the car's fuel. Prices more than a week old are left out, as everywhere a
 * price is quoted as cheapest (`Station.hasCurrentPrice`).
 */
struct FullTank: Equatable, Sendable {
    /** Cents per litre at the cheapest station. */
    let cheapestPrice: Double
    /** Dollars for a full tank. */
    let cheapest: Double
    let average: Double
    let dearest: Double
    /** How far out the prices were taken, in km. */
    let withinKm: Int

    /** Where the average sits between cheapest (0) and dearest (1). */
    var averagePosition: Double { dearest > cheapest ? (average - cheapest) / (dearest - cheapest) : 0.5 }
    var spread: Double { dearest - cheapest }

    /**
     * Prices within `withinKm` of the centre; when none is that close, every station loaded
     * (`loadedKm` out). Nil without a current price or a tank size.
     */
    static func near(_ stations: [Station], fuel: FuelType, litres: Int, withinKm: Int = 5, loadedKm: Int, now: Date = .now) -> FullTank? {
        guard litres > 0 else { return nil }
        let current = stations.filter { $0.hasCurrentPrice(fuel, now: now) }
        let close = current.filter { ($0.distance ?? .infinity) <= Double(withinKm) }
        let (pool, km) = close.isEmpty ? (current, loadedKm) : (close, withinKm)
        let prices = pool.compactMap { $0.price(fuel)?.price }
        guard let low = prices.min(), let high = prices.max() else { return nil }
        let mean = prices.reduce(0, +) / Double(prices.count)
        let tank = Double(litres) / 100
        return FullTank(cheapestPrice: low, cheapest: low * tank, average: mean * tank, dearest: high * tank, withinKm: km)
    }
}

/** Totals for the fill-ups logged in the current car, for "In this car". */
struct CarHistory: Equatable, Sendable {
    let count: Int
    let litres: Double
    /** Litre-weighted average paid, cents per litre. */
    let averagePaid: Double
    let since: Date

    /** Fill-ups from `since` on (every fill-up when nil); nil when there are none. */
    static func of(_ log: [FillUp], since: Date?) -> CarHistory? {
        let fills = since.map { start in log.filter { $0.date >= start } } ?? log
        guard let first = fills.map(\.date).min() else { return nil }
        let litres = fills.map(\.litres).reduce(0, +)
        let paid = fills.map { $0.litres * $0.centsPerLitre }.reduce(0, +)
        return CarHistory(count: fills.count, litres: litres, averagePaid: litres > 0 ? paid / litres : 0, since: since ?? first)
    }
}

/** Dollars and cents for a tank or a fill-up, "$125.27". */
func money(_ dollars: Double) -> String {
    dollars.formatted(.currency(code: "AUD"))
}
