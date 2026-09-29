import Foundation

// Mirrors packages/web/src/lib/place-names.ts until casing moves into the ingest adapters,
// which would let both clients drop their copy.
private let keepUpper: Set<String> = ["NSW", "QLD", "VIC", "WA", "SA", "TAS", "ACT", "NT", "BP", "EG", "IOR", "OMG", "UGO", "PO"]

private func recasePart(_ part: Substring) -> String {
    let s = String(part)
    if keepUpper.contains(s) || s.contains(where: \.isNumber) { return s }
    var out = ""
    var capitalise = true
    for ch in s.lowercased() {
        out.append(capitalise ? Character(ch.uppercased()) : ch)
        capitalise = ch == "'"
    }
    return out
}

/** Title-cases all-caps place and station names; mixed-case text is left as sent. */
func titleCasePlace(_ text: String) -> String {
    guard text == text.uppercased() else { return text }
    return text.split(separator: " ", omittingEmptySubsequences: false).map { word in
        word.split(separator: "-", omittingEmptySubsequences: false).map(recasePart).joined(separator: "-")
    }.joined(separator: " ")
}

extension Station {
    var displayCased: Station {
        Station(id: id, name: titleCasePlace(name), brand: brand, address: titleCasePlace(address),
                suburb: titleCasePlace(suburb), state: state, postcode: postcode, lat: lat, lng: lng,
                prices: prices, distance: distance)
    }

    /** Address without repeating a suburb the feed already put in it. */
    var addressLine: String {
        address.lowercased().contains(suburb.lowercased()) ? address : "\(address), \(suburb) \(state.uppercased()) \(postcode)"
    }
}
