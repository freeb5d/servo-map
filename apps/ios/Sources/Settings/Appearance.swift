import SwiftUI

/** The app's look, chosen in Settings › Appearance and applied app-wide with `preferredColorScheme`. */
enum Appearance: String, CaseIterable, Identifiable {
    /** Follows the iPhone: paper by day, ink by night if the iPhone switches. */
    case system
    /** Always the light theme, 紙. */
    case paper
    /** Always the dark theme, 墨. */
    case ink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .paper: "Paper"
        case .ink: "Ink"
        }
    }

    var note: String {
        switch self {
        case .system: "Follows this iPhone"
        case .paper: "Light, like washi"
        case .ink: "Dark, like sumi"
        }
    }

    /** nil lets the system decide. */
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .paper: .light
        case .ink: .dark
        }
    }
}
