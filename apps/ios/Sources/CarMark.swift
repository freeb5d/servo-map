import SwiftUI
import UIKit

/**
 * A car make's mark (decision 0008): the Simple Icons mark (Resources/CarLogos.xcassets, copied from
 * design/car-logos) in ink on a white 1:1 tile, or, for a make without one, its monogram on the same
 * tile, as brand marks do (decision 0003).
 */
struct CarMark: View {
    let make: String
    var size: CGFloat = 32

    var body: some View {
        Group {
            if UIImage(named: asset) != nil {
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.19)
            } else {
                Text(CarMake.monogram(make))
                    .font(ServoMapFont.body(.caption, weight: 700, size: size * 0.24))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            }
        }
        .foregroundStyle(ServoMapColor.brandTileInk)
        .frame(width: size, height: size)
        .background(ServoMapColor.brandTile, in: shape)
        .overlay(shape.strokeBorder(ServoMapColor.brandTileLine, lineWidth: 0.5))
        .accessibilityElement()
        .accessibilityLabel(make)
        // A mark, not reading text: it keeps its size at every Dynamic Type setting.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private var asset: String { "car-\(CarMake.slug(make))" }
    /** The brand tile's corner, 24 % of its edge (docs/design/system.md, BrandSeal). */
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: size * 0.24, style: .continuous) }
}
