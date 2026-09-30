import Foundation

// Station names, addresses and suburbs arrive title-cased from the worker's ingest adapters
// (packages/worker/src/utils/place-names.ts); only the address line is composed here.
extension Station {
    /** Address without repeating a suburb the feed already put in it. */
    var addressLine: String {
        address.lowercased().contains(suburb.lowercased()) ? address : "\(address), \(suburb) \(state.uppercased()) \(postcode)"
    }
}
