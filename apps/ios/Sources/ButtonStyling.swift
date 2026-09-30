import SwiftUI

extension View {
    /**
     * Buttons in their own weight. The app's default font is the small caption size, so section
     * headers come out small; without this every button inherited that thin 13 pt text and read
     * as blurred on glass. Actions are semibold at the body size, as in the system apps.
     */
    func actionFont() -> some View {
        font(ServoMapFont.body(.body, weight: 600))
    }
}
