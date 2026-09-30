import SwiftUI

/**
 * A car's picture from the website (`/cars/…`, decision 0008): a white studio render laid on the
 * paper with multiply, so its white ground disappears. While it loads, or where there is none, the
 * make's mark stands in. On the dark theme the render sits on its own white tile, since multiply
 * would darken a white car into the page.
 */
struct CarPicture: View {
    /** Site path, from `Vehicle.imagePath` or `VehicleImage.path`. */
    let path: String
    /** The make whose mark stands in; nil for a car entered by hand. */
    let make: String?
    /** What the picture shows, for VoiceOver: "Mazda CX-5". */
    let subject: String
    /** Adds the "Illustration" note where the page names the car. */
    var labelled = false
    /** Size of the make's mark while the picture loads. */
    var markSize: CGFloat = 56
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        AsyncImage(url: API.site.appending(path: path), transaction: Transaction(animation: ServoMapMotion.standard)) { phase in
            if let image = phase.image {
                picture(image)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottomTrailing) {
                        // Only a render is an illustration of the car; the stand-in mark is not.
                        if labelled {
                            Text("Illustration").font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                        }
                    }
            } else {
                standIn
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Illustration of a \(subject)")
    }

    @ViewBuilder private func picture(_ image: Image) -> some View {
        if scheme == .dark {
            image.resizable().scaledToFit()
                .blendMode(.multiply)
                .background(ServoMapColor.brandTile, in: RoundedRectangle(cornerRadius: ServoMapRadius.r3))
        } else {
            image.resizable().scaledToFit().blendMode(.multiply)
        }
    }

    @ViewBuilder private var standIn: some View {
        if let make {
            CarMark(make: make, size: markSize)
        } else {
            Image(systemName: "car.side").font(ServoMapFont.display(.largeTitle)).foregroundStyle(ServoMapColor.ink3)
        }
    }
}
