import SwiftUI

/**
 * The tabs drawn straight onto the sheet's glass when it is pulled all the way down, as Find My
 * does. The system tab bar brings its own capsule, which inside the floating sheet reads as a
 * second ring; this row has none. Picking a tab also raises the sheet.
 */
struct CollapsedTabBar: View {
    @Binding var tab: String
    let pick: (String) -> Void

    /**
     * The glass bar less an even inset on every side, so the pill runs concentric with it. The
     * system draws the collapsed sheet's content at about 0.86 scale, so these are content points:
     * 68 and 9 come out as the 8 pt screen inset measured on the simulator.
     */
    static let pillHeight: CGFloat = 68

    static let items: [(value: String, title: String, symbol: String)] = [
        ("map", "Nearby", "fuelpump"),
        ("trends", "Trends", "chart.line.uptrend.xyaxis"),
        ("saved", "Saved", "bookmark"),
        ("log", "Log", "list.bullet.rectangle"),
        ("search", "Search", "magnifyingglass"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.items, id: \.value) { item in
                let selected = tab == item.value
                Button { pick(item.value) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .symbolVariant(selected && item.value != "search" ? .fill : .none)
                            .font(ServoMapFont.body(.title3, weight: 400, size: 21))
                            .frame(height: 26)
                        Text(item.title).font(ServoMapFont.body(.caption, weight: selected ? 700 : 500, size: 11))
                    }
                    .foregroundStyle(ServoMapColor.ink)
                    // The pill fills the bar less an even inset, so its round ends run concentric
                    // with the bar's, as the selected tab does in Find My.
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.pillHeight)
                    .background(selected ? ServoMapColor.wash : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 9)
    }
}
