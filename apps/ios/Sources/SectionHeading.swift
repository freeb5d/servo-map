import SwiftUI

/** A page section's title in Mincho with an optional quiet link or note at the right. */
struct SectionHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(ServoMapFont.display(.title3)).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing.font(ServoMapFont.body(.footnote, weight: 600))
        }
    }
}

extension SectionHeading where Trailing == EmptyView {
    init(title: String) { self.init(title: title) { EmptyView() } }
}
