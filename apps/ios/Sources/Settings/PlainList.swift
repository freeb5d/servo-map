import SwiftUI

/**
 * The 素 plain list (decision 0008): rows straight on paper inside the page's gutters, groups under
 * Mincho titles, and a hairline only between rows, inset to the text. No cards around groups.
 */
struct PlainPage<Content: View>: View {
    /** One sentence under the large title saying what the page decides. */
    var intro: String?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let intro {
                    Text(intro).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, ServoMapSpace.x2)
                }
                content
            }
            .padding(.horizontal, ServoMapList.gutter)
            .padding(.bottom, ServoMapSpace.x7)
        }
        .background(ServoMapColor.bg)
        .navigationBarTitleDisplayMode(.large)
    }
}

/** A group of rows under a Mincho title, with hairlines between the rows and an optional note below. */
struct PlainGroup<Content: View>: View {
    var title: String?
    var footer: String?
    /** Where the hairline starts: past the line icon on rows that have one. */
    var inset: CGFloat = ServoMapList.iconSize + ServoMapList.iconGap
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title).font(ServoMapFont.display(.title3, weight: 600)).foregroundStyle(ServoMapColor.ink)
                    .padding(.bottom, ServoMapSpace.x1)
                    .accessibilityAddTraits(.isHeader)
            }
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    if row.id != rows.first?.id { PlainHairline(inset: inset) }
                    row
                }
            }
            if let footer {
                Text(footer).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ServoMapSpace.x2)
            }
        }
        .padding(.top, ServoMapList.groupGap)
    }
}

/** The rule between two rows. */
struct PlainHairline: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle().fill(ServoMapColor.line).frame(height: ServoMapList.hairline).padding(.leading, inset)
            .accessibilityHidden(true)
    }
}

/**
 * One row: a plain SF Symbol line icon (no tile behind it), the title and an optional note, the
 * current value, and a chevron when it opens a page.
 */
struct PlainRow: View {
    var icon: String?
    let title: String
    var subtitle: String?
    var value: String?
    var chevron = true
    var tint: Color = ServoMapColor.ink

    var body: some View {
        HStack(spacing: ServoMapList.iconGap) {
            if let icon {
                Image(systemName: icon)
                    .font(ServoMapFont.body(.title3, weight: 400))
                    .frame(width: ServoMapList.iconSize)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ServoMapFont.lead).foregroundStyle(tint)
                if let subtitle {
                    Text(subtitle).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                }
            }
            Spacer(minLength: ServoMapSpace.x2)
            if let value {
                Text(value).font(ServoMapFont.lead).foregroundStyle(ServoMapColor.ink3).monospacedDigit()
                    .lineLimit(1)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(ServoMapFont.body(.footnote, weight: 600)).foregroundStyle(ServoMapColor.ink3)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: ServoMapList.rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/** A row that acts: pressing washes the row's background, the only feedback 素 allows. */
struct PlainRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                ServoMapColor.wash
                    .padding(.horizontal, -ServoMapSpace.x2)
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            .animation(ServoMapMotion.standard, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PlainRowButtonStyle {
    static var plainRow: PlainRowButtonStyle { PlainRowButtonStyle() }
}

/**
 * A row with a system switch, an optional small sketch before it and a note under the title. The
 * sketch and the switch sit at the top, so a title that wraps keeps every line beside them.
 */
struct PlainToggleRow<Leading: View>: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    @ViewBuilder var leading: Leading

    var body: some View {
        HStack(alignment: .top, spacing: ServoMapSpace.x3) {
            leading.padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ServoMapFont.lead).foregroundStyle(ServoMapColor.ink)
                if let subtitle {
                    Text(subtitle).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .accessibilityHint(subtitle ?? "")
        }
        .padding(.vertical, ServoMapSpace.x3)
        .frame(minHeight: ServoMapList.rowHeight)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

extension PlainToggleRow where Leading == EmptyView {
    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.init(title: title, subtitle: subtitle, isOn: isOn) { EmptyView() }
    }
}

/** A choice among a few, as a row with a checkmark on the chosen one. */
struct PlainChoiceRow<Leading: View>: View {
    let title: String
    var subtitle: String?
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var leading: Leading

    var body: some View {
        Button(action: action) {
            HStack(spacing: ServoMapSpace.x3 + 2) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(ServoMapFont.lead).foregroundStyle(ServoMapColor.ink)
                    if let subtitle {
                        Text(subtitle).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                    }
                }
                Spacer(minLength: ServoMapSpace.x2)
                Image(systemName: "checkmark")
                    .font(ServoMapFont.body(.body, weight: 600))
                    .foregroundStyle(ServoMapColor.ink)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, ServoMapSpace.x2)
            .frame(minHeight: ServoMapList.rowHeight + ServoMapSpace.x2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainRow)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}
