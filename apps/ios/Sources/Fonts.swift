import CoreText
import SwiftUI
import UIKit

/**
 * The bundled faces (Resources/Fonts, see scripts/fetch_fonts.sh) are registered at launch
 * rather than listed in Info.plist, so adding a weight is a file drop plus a token change.
 */
enum Fonts {
    static func register() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /**
     * The owner kept the accent as ink, and the glass tab bar always draws unselected tabs in the
     * primary colour, so colour cannot tell them apart. Weight does: the selected label is bold.
     * (Icons switch between filled and outline in MapScreen.)
     */
    private static func styleTabBar() {
        let regular = UIFont.systemFont(ofSize: 10, weight: .medium)
        let bold = UIFont.systemFont(ofSize: 10, weight: .bold)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.titleTextAttributes = [.font: regular]
            item.selected.titleTextAttributes = [.font: bold]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /** Large titles in Mincho; inline titles stay in the system face, like the rest of the interface text. */
    static func styleNavigationBars() {
        guard let large = UIFont(name: ServoMapFont.displayFace(500), size: 32) else { return }
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        styleTabBar()
    }
}
