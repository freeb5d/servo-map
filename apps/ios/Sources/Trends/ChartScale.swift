import Foundation

/** Round axis ranges and tick values for the Trends charts, so every scale reads in whole steps. */
enum ChartScale {
    /** A step of 1, 2, 2.5 or 5 × 10ⁿ, close to `span / ticks`. */
    static func step(for span: Double, ticks: Int) -> Double {
        guard span > 0, ticks > 0 else { return 1 }
        let raw = span / Double(ticks)
        let magnitude = pow(10, (log10(raw)).rounded(.down))
        let fraction = raw / magnitude
        let nice: Double = fraction <= 1 ? 1 : fraction <= 2 ? 2 : fraction <= 2.5 ? 2.5 : fraction <= 5 ? 5 : 10
        return nice * magnitude
    }

    /**
     * The values' range widened by `pad` and rounded out to whole steps, with the ticks inside it.
     * A single value (or none) still gets a scale one step wide.
     */
    static func nice(_ values: [Double], ticks: Int = 3, pad: Double = 0) -> (domain: ClosedRange<Double>, ticks: [Double]) {
        guard let lo = values.min(), let hi = values.max() else { return (0...1, [0, 1]) }
        let s = step(for: max(hi - lo + 2 * pad, 1), ticks: ticks)
        let bottom = ((lo - pad) / s).rounded(.down) * s
        let top = max(((hi + pad) / s).rounded(.up) * s, bottom + s)
        return (bottom...top, Array(stride(from: bottom, through: top + s / 1000, by: s)))
    }
}
