import SwiftUI

/** Settings › Appearance: follow the iPhone, or keep to paper (light) or ink (dark). */
struct AppearanceScreen: View {
    @AppStorage(StorageKey.appearance) private var appearance = Appearance.system.rawValue

    var body: some View {
        PlainPage(intro: "ServoMap follows this iPhone, or stays on paper or ink.") {
            PlainGroup(inset: 0) {
                ForEach(Appearance.allCases) { option in
                    PlainChoiceRow(title: option.title, subtitle: option.note,
                                   selected: (Appearance(rawValue: appearance) ?? .system) == option) {
                        appearance = option.rawValue
                    } leading: {
                        Swatch(appearance: option)
                    }
                }
            }
        }
    }
}

/** A small page in the theme: its paper with a line of ink; System shows both halves. */
private struct Swatch: View {
    let appearance: Appearance

    var body: some View {
        HStack(spacing: 0) {
            switch appearance {
            case .system: half(.light); half(.dark)
            case .paper: half(.light)
            case .ink: half(.dark)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: ServoMapRadius.r3))
        .overlay(RoundedRectangle(cornerRadius: ServoMapRadius.r3).strokeBorder(ServoMapColor.line, lineWidth: ServoMapList.hairline))
        .accessibilityHidden(true)
    }

    /** The tokens resolved in one theme, whatever the app is showing now. */
    private func half(_ scheme: ColorScheme) -> some View {
        ZStack {
            ServoMapColor.bg
            Text("素").font(ServoMapFont.display(.body, weight: 600, size: 15)).foregroundStyle(ServoMapColor.ink)
        }
        .environment(\.colorScheme, scheme)
    }
}
