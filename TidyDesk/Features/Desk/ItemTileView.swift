import SwiftUI
import UIKit

/// Visual of one desk object at a given cell size. Purely presentational (no gestures).
struct ItemTileView: View {
    let item: TechItem
    let cellSize: CGFloat
    /// 0 = resting on the desk, 1 = fully lifted. Animatable: the shadow grows deeper, softer
    /// and further offset as the item rises, which fakes height on a flat 2D desk.
    var elevation: CGFloat = 0
    var isWarning = false

    var body: some View {
        let width = CGFloat(item.gridWidth) * cellSize
        let height = CGFloat(item.gridHeight) * cellSize
        let inset = max(2, cellSize * 0.06)
        let radius = cellSize * 0.22
        let color = Theme.color(for: item.category)
        let symbolSide = min(width, height) * 0.56

        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color.gradient)
            .overlay {
                // Thin light edge = soft matte-plastic / aluminium look.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: max(1, cellSize * 0.022))
            }
            .overlay {
                ItemArtwork(imageName: item.imageName)
                    .frame(width: symbolSide, height: symbolSide)
                    .rotationEffect(.degrees(item.isRotated ? 90 : 0))
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            }
            .overlay {
                if isWarning {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Theme.invalid, lineWidth: 3)
                }
            }
            .padding(inset)
            .frame(width: width, height: height)
            // Contact shadow (tight, always there) + cast shadow (grows with elevation).
            .shadow(color: .black.opacity(0.10 * (1 - elevation * 0.5)), radius: 2, y: 1.5)
            .shadow(color: .black.opacity(0.34 * elevation),
                    radius: 4 + 16 * elevation,
                    y: 2 + 14 * elevation)
            .accessibilityElement()
            .accessibilityLabel(Text(item.name))
            .accessibilityValue(Text("\(item.gridWidth) by \(item.gridHeight)"))
    }
}

/// Real artwork from the asset catalog when present, otherwise the SF Symbol of the same name.
struct ItemArtwork: View {
    let imageName: String
    /// Colour for SF Symbol fallbacks (real artwork keeps its own colours).
    var tint: Color = .white.opacity(0.95)

    var body: some View {
        if UIImage(named: imageName) != nil {
            Image(imageName).resizable().scaledToFit()
        } else {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    HStack {
        ItemTileView(item: TechItem(name: "Keyboard", widthInGrid: 4, heightInGrid: 1, imageName: "keyboard.fill", category: .peripheral), cellSize: 56)
        ItemTileView(item: TechItem(name: "Monitor", widthInGrid: 3, heightInGrid: 2, imageName: "display", category: .display), cellSize: 56, elevation: 1)
    }
    .padding()
    .background(Theme.background)
}
