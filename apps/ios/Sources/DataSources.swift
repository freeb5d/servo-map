import SwiftUI

/**
 * Where prices come from, as each state's licence requires (decision 0007). The sources, their
 * statements and report links come from `DataSource.byState`, generated from `@servo-map/shared`.
 */
extension DataSource {
    /** The source for a station's state code (the API's "nsw", "act", …; any case). */
    static func forState(_ code: String) -> DataSource? { byState[code.lowercased()] }

    /** The licence statement for this year, when the licence prescribes one. */
    var statement: String? { attribution(year: Calendar.current.component(.year, from: .now)) }

    /** Whether the licence asks for more than the credit line: a statement or a report link. */
    var hasNotice: Bool { statement != nil || reportURL != nil }
}

/** "via NSW FuelCheck", under a station's price. */
struct SourceCredit: View {
    let state: String

    var body: some View {
        if let source = DataSource.forState(state) {
            Text("via \(source.name)").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
        }
    }
}

/** The licence statement and, where required, the way to report a stale price; a footnote on a station. */
struct SourceNotice: View {
    let state: String

    var body: some View {
        if let source = DataSource.forState(state), source.hasNotice {
            VStack(alignment: .leading, spacing: 8) {
                if let statement = source.statement {
                    Text(statement).font(ServoMapFont.body(.caption2)).foregroundStyle(ServoMapColor.ink3)
                }
                if let url = report(source) {
                    Link(destination: url) {
                        Label("Price out of date? Report it to Consumer and Business Services", systemImage: "exclamationmark.bubble")
                            .font(ServoMapFont.small)
                    }
                }
            }
        }
    }

    private func report(_ source: DataSource) -> URL? { source.reportURL.flatMap(URL.init(string:)) }
}

/** One row per state with live prices: the scheme, how it reports, a link, and its statement. */
struct DataSourcesScreen: View {
    @Environment(Store.self) private var store

    var body: some View {
        List {
            Section {
                ForEach(store.liveStates, id: \.self) { code in
                    if let source = DataSource.forState(code) { row(code, source) }
                }
            } footer: {
                Text("ServoMap shows the prices each state's reporting scheme publishes. Prices can change after they are reported.")
                    .font(ServoMapFont.small)
            }
        }
        .paperList()
    }

    private func row(_ code: String, _ source: DataSource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(source.name).font(ServoMapFont.body(.body, weight: 600))
                Spacer()
                Text(code.uppercased()).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
            }
            Text(source.note).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
            if let url = URL(string: source.url) {
                Link(url.host() ?? source.url, destination: url).font(ServoMapFont.small)
            }
            SourceNotice(state: code)
        }
        .padding(.vertical, 4)
        .paperRow()
    }
}
