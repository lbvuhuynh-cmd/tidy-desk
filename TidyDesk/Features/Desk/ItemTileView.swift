import SwiftUI

/// Visual of one desk object at a given cell size. Purely presentational (no gestures).
///
/// Two looks, picked automatically by `ItemArt`:
/// * **Artwork** (top-down vector asset present): the picture *is* the object. It fills the footprint
///   (aspect-fit, small padding) over a faint category-tinted base that marks the occupied cells, and the shadows
///   follow the drawing's own silhouette, so a keyboard casts a keyboard-shaped shadow on the wooden desk.
/// * **Placeholder** (no asset yet): the coloured category tile with an SF Symbol, as before.
///
/// Rotation: art is drawn in its authored orientation (`widthInGrid × heightInGrid`) and turned 90° as a whole,
/// so a rotated keyboard is the same drawing standing upright, never a squashed one.
struct ItemTileView: View {
    let item: TechItem
    let cellSize: CGFloat
    /// 0 = resting on the desk, 1 = fully lifted. Animatable: the shadow grows deeper, softer
    /// and further offset as the item rises, which fakes height on a flat 2D desk.
    var elevation: CGFloat = 0
    var isWarning = false

    var body: some View {
        let art = ItemArt.resolve(for: item)
        let width = CGFloat(item.gridWidth) * cellSize
        let height = CGFloat(item.gridHeight) * cellSize
        let inset = max(2, cellSize * 0.06)          // keeps neighbouring items visibly separate on the grid
        let innerW = width - inset * 2, innerH = height - inset * 2
        let radius = cellSize * 0.22

        Group {
            if art.isAsset {
                artworkTile(art, innerW: innerW, innerH: innerH, radius: radius)
            } else {
                placeholderTile(art, innerW: innerW, innerH: innerH, radius: radius)
            }
        }
        .padding(inset)
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel(Text(item.name))
        .accessibilityValue(Text("\(item.gridWidth) by \(item.gridHeight)"))
    }

    // MARK: Artwork (vector asset)

    private func artworkTile(_ art: ItemArt, innerW: CGFloat, innerH: CGFloat, radius: CGFloat) -> some View {
        let color = Theme.color(for: item.category)
        // Small breathing room inside the footprint so art never touches the cell edge.
        let artPadding = min(innerW, innerH) * 0.06
        return ZStack {
            // Footprint base: barely-there tint marking the occupied cells; fades out while lifted
            // (the drag preview shows the footprint instead).
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color.opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(isWarning ? Theme.invalid : color.opacity(0.28), lineWidth: isWarning ? 3 : 1)
                }
                .opacity(isWarning ? 1 : 1 - elevation)

            orientedArt(art, innerW: innerW, innerH: innerH, symbolTint: .white)
                .padding(artPadding)
                // Shadows follow the drawing's alpha: contact shadow + cast shadow growing with elevation.
                .shadow(color: .black.opacity(0.18 * (1 - elevation * 0.5)), radius: 1.5, y: 1)
                .shadow(color: .black.opacity(0.30 * elevation), radius: 3 + 14 * elevation, y: 2 + 12 * elevation)
        }
        .frame(width: innerW, height: innerH)
    }

    // MARK: Placeholder (no asset yet)

    private func placeholderTile(_ art: ItemArt, innerW: CGFloat, innerH: CGFloat, radius: CGFloat) -> some View {
        let color = Theme.color(for: item.category)
        let symbolSide = min(innerW, innerH) * 0.6
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color.gradient)
            .overlay {
                // Thin light edge = soft matte-plastic / aluminium look.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: max(1, cellSize * 0.022))
            }
            .overlay {
                ItemArtworkView(art: art)
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
            .frame(width: innerW, height: innerH)
            // Contact shadow (tight, always there) + cast shadow (grows with elevation).
            .shadow(color: .black.opacity(0.10 * (1 - elevation * 0.5)), radius: 2, y: 1.5)
            .shadow(color: .black.opacity(0.34 * elevation), radius: 4 + 16 * elevation, y: 2 + 14 * elevation)
    }

    /// Lays the art out in its authored orientation, then turns it 90° when the item is rotated.
    /// (`rotationEffect` doesn't change layout, so the outer frame restores the current footprint.)
    private func orientedArt(_ art: ItemArt, innerW: CGFloat, innerH: CGFloat, symbolTint: Color) -> some View {
        ItemArtworkView(art: art, symbolTint: symbolTint)
            .frame(width: item.isRotated ? innerH : innerW, height: item.isRotated ? innerW : innerH)
            .rotationEffect(.degrees(item.isRotated ? 90 : 0))
            .frame(width: innerW, height: innerH)
    }
}

#Preview("Placeholders (no assets yet)") {
    VStack(spacing: 16) {
        ItemTileView(item: TechItem(name: "Keyboard", widthInGrid: 4, heightInGrid: 1, imageName: "keyboard_mechanical",
                                    symbolName: "keyboard.fill", category: .peripheral), cellSize: 56)
        ItemTileView(item: TechItem(name: "Monitor", widthInGrid: 3, heightInGrid: 2, imageName: "monitor",
                                    symbolName: "display", category: .display), cellSize: 56, elevation: 1)
    }
    .padding()
    .background(Theme.desk)
}
