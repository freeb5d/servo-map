import SwiftUI

/** A Trends module: a Mincho title with a quiet note on the right, then its content. Space groups it, not a box. */
struct TrendsSection<Content: View>: View {
    let title: String?
    var note: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(ServoMapFont.display(.title3, weight: 600)).foregroundStyle(ServoMapColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    if let note { Text(note).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3) }
                }
            }
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }
}

/** The page's one-sentence fact, in Mincho, under a small dated caption. */
struct FactLine: View {
    let caption: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let caption { Text(caption).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3) }
            Text(text).font(ServoMapFont.display(.title3, weight: 500, size: 21)).foregroundStyle(ServoMapColor.ink)
                .lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}

/** A sentence under a chart that says what it shows in figures. */
struct ChartNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink2)
            .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }
}

/** One figure in a ruled row. */
struct RuledFigure: Identifiable {
    let label: String
    let value: String
    var color: Color = ServoMapColor.ink
    var id: String { label }
}

/** Headline figures unboxed between two hairlines, like a newspaper table (no KPI tiles). */
struct RuledFigures: View {
    let figures: [RuledFigure]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(figures.enumerated()), id: \.element.id) { index, figure in
                VStack(alignment: .leading, spacing: 2) {
                    Text(figure.label).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                    Text(figure.value).font(ServoMapFont.display(.title3, weight: 600, size: 19)).monospacedDigit()
                        .foregroundStyle(figure.color).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.leading, index == 0 ? 0 : 10)
                .overlay(alignment: .leading) {
                    if index > 0 { Rectangle().fill(ServoMapColor.line).frame(width: 0.5) }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
        .padding(.horizontal, 20)
    }
}

/** A row of capsule choices: the selected one filled with ink, the rest outlined. */
struct ChoiceChips<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { withAnimation(ServoMapMotion.snappy) { selection = option } } label: {
                    Text(label(option))
                        .font(ServoMapFont.body(.footnote, weight: selected ? 600 : 400))
                        .foregroundStyle(selected ? ServoMapColor.onAccent : ServoMapColor.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 30)
                        .background { if selected { Capsule().fill(ServoMapColor.accent) } }
                        .overlay { if !selected { Capsule().strokeBorder(ServoMapColor.line, lineWidth: 0.5) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/** Legend keys drawn with the marks they stand for. */
enum LegendKey {
    case dot(Color), ring(Color), line(Color), swatch(Color), bar(Color)
}

struct Legend: View {
    let items: [(LegendKey, String)]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    key(item.0)
                    Text(item.1)
                }
            }
        }
        .font(ServoMapFont.small)
        .foregroundStyle(ServoMapColor.ink2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func key(_ key: LegendKey) -> some View {
        switch key {
        case .dot(let c): Circle().fill(c).frame(width: 9, height: 9)
        case .ring(let c): Circle().strokeBorder(c, lineWidth: 2).frame(width: 9, height: 9)
        case .line(let c): Rectangle().fill(c).frame(width: 14, height: 2)
        case .swatch(let c): Rectangle().fill(c).frame(width: 14, height: 9)
        case .bar(let c): Capsule().fill(c).frame(width: 16, height: 3)
        }
    }
}

/** The page's closing credit: where its prices come from (decision 0007), any licence notices, and a note. */
struct SourceLine: View {
    let states: [String]
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let text = [note, StateFacts.credit(states)].compactMap { $0 }.joined(separator: " ")
            Text(text).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            ForEach(states, id: \.self) { SourceNotice(state: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .overlay(alignment: .top) { Hairline() }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 32)
    }
}

/** A quiet stand-in while a page's data loads or when it could not be fetched. */
struct TrendsPlaceholder: View {
    let failed: Bool

    var body: some View {
        Text(failed ? "Trends could not be loaded. Pull to try again." : "Loading…")
            .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
    }
}
