import SwiftUI

/// The desk: empty grid spots, the snap ghost, and the items on it.
struct DeskSurfaceView: View {
    let vm: DeskDragViewModel
    let cellSize: CGFloat

    var body: some View {
        let grid = vm.grid
        let cleared = vm.isLevelClear
        let radius = cellSize * 0.42

        ZStack(alignment: .topLeading) {
            ForEach(0..<(grid.rows * grid.columns), id: \.self) { index in
                RoundedRectangle(cornerRadius: cellSize * 0.18, style: .continuous)
                    .fill(Theme.slot.opacity(cleared ? 0 : 1))
                    .padding(cellSize * 0.07)
                    .frame(width: cellSize, height: cellSize)
                    .offset(x: CGFloat(index % grid.columns) * cellSize,
                            y: CGFloat(index / grid.columns) * cellSize)
            }

            // Fixed-target levels: faint outline + icon where each item belongs (from `correctPosition`).
            ForEach(vm.targetItems) { item in
                if let target = item.targetPosition {
                    TargetOutlineView(item: item, cellSize: cellSize, isFilled: item.isAtTarget && item.isPlaced)
                        .offset(x: CGFloat(target.column) * cellSize, y: CGFloat(target.row) * cellSize)
                        .opacity(cleared ? 0 : 1)
                        .allowsHitTesting(false)
                }
            }

            if let hover = vm.hover {
                // Live preview, layer 1: tint every desk cell the item would cover (green = fits, red = no).
                CellHighlightLayer(cells: hover.visibleCells(rows: grid.rows, columns: grid.columns)
                                       .filter { !hover.blockedCells.contains($0) },
                                   color: hover.isValid ? Theme.valid : Theme.invalid,
                                   strength: hover.isValid ? 0.38 : 0.22,
                                   cellSize: cellSize)
                SnapGhostView(preview: hover, cellSize: cellSize)
                    .offset(x: CGFloat(hover.origin.column) * cellSize, y: CGFloat(hover.origin.row) * cellSize)
                    .animation(.spring(response: 0.16, dampingFraction: 0.8), value: hover.origin)
                    .allowsHitTesting(false)
            }

            ForEach(vm.placedItems) { item in
                if let origin = item.currentPosition {
                    DraggableItemView(item: item, vm: vm, cellSize: cellSize)
                        .modifier(ItemDoneEffect(placements: vm.placementCounts[item.id, default: 0],
                                                 cornerRadius: cellSize * 0.22))
                        .modifier(ClearGlowEffect(isCleared: cleared,
                                                  delay: 0.2 + Double(origin.row + origin.column) * 0.06,
                                                  cornerRadius: cellSize * 0.22,
                                                  inset: max(2, cellSize * 0.06)))
                        .offset(x: CGFloat(origin.column) * cellSize, y: CGFloat(origin.row) * cellSize)
                }
            }

            // Live preview, layer 2: cells blocked by another item, painted *over* that item
            // so the player sees exactly what is in the way.
            if let hover = vm.hover, !hover.blockedCells.isEmpty {
                CellHighlightLayer(cells: Array(hover.blockedCells), color: Theme.invalid,
                                   strength: 0.55, cellSize: cellSize)
            }
        }
        .frame(width: CGFloat(grid.columns) * cellSize, height: CGFloat(grid.rows) * cellSize, alignment: .topLeading)
        .reportFrame(FrameKey.board)
        .padding(cellSize * 0.22)
        .background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Theme.desk)
                .overlay {
                    // Desk edge; turns into a soft LED strip when the setup is complete.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(AngularGradient(colors: Theme.led, center: .center), lineWidth: 4)
                        .opacity(cleared ? 1 : 0)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Theme.deskEdge, lineWidth: 2)
                        .opacity(cleared ? 0 : 1)
                }
                .shadow(color: cleared ? Theme.led[1].opacity(0.55) : .black.opacity(0.08),
                        radius: cleared ? 22 : 8, y: cleared ? 0 : 4)
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: cleared) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.0, duration: 0.15)   // let the last snap land first
                SpringKeyframe(1.04, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: cleared)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Desk, \(grid.columns) by \(grid.rows)"))
    }
}

/// "Item done" feedback when the player sets an item down: a small pop plus a glow ring that expands and fades.
/// Not played for messy items that are on the desk when the level starts.
private struct ItemDoneEffect: ViewModifier {
    let placements: Int
    let cornerRadius: CGFloat
    @State private var trigger = 0

    private struct Values {
        var scale: CGFloat = 1
        var ringScale: CGFloat = 1
        var ringOpacity: Double = 0
    }

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view
                    .scaleEffect(value.scale)
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Theme.valid, lineWidth: 3)
                            .scaleEffect(value.ringScale)
                            .opacity(value.ringOpacity)
                    }
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.1, duration: 0.09)
                    SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                }
                KeyframeTrack(\.ringScale) {
                    LinearKeyframe(0.95, duration: 0.01)
                    CubicKeyframe(1.35, duration: 0.5)
                }
                KeyframeTrack(\.ringOpacity) {
                    LinearKeyframe(0.9, duration: 0.02)
                    CubicKeyframe(0, duration: 0.5)
                }
            }
            .onAppear { if placements > 0 { trigger += 1 } }
            .onChange(of: placements) { trigger += 1 }
    }
}

/// Level-clear "border flash": a wave (top-left -> bottom-right, staggered by `delay`) lights an LED-gradient
/// outline around every device, flares, then settles into a soft steady glow while the desk is complete.
private struct ClearGlowEffect: ViewModifier {
    let isCleared: Bool
    let delay: Double
    let cornerRadius: CGFloat
    let inset: CGFloat

    @State private var strength: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AngularGradient(colors: Theme.led, center: .center), lineWidth: 2.5)
                    .padding(inset)
                    .opacity(strength)
                    .allowsHitTesting(false)
            }
            .shadow(color: Theme.led[1].opacity(0.7 * strength), radius: 10 * strength)
            .brightness(0.12 * max(0, strength - 0.4))
            .task(id: isCleared) {
                guard isCleared else {
                    strength = 0
                    return
                }
                // `try` (not `try?`): a Replay mid-wave cancels the task and must not light anything up.
                do {
                    try await Task.sleep(for: .seconds(delay))                    // wait for this item's turn in the wave
                    withAnimation(.easeOut(duration: 0.18)) { strength = 1 }      // flash
                    try await Task.sleep(for: .milliseconds(180))
                    withAnimation(.easeInOut(duration: 0.6)) { strength = 0.35 }  // settle into a soft glow
                } catch {
                    strength = 0
                }
            }
    }
}

/// "Dock mark" for a fixed-target item: dashed outline in the item's colour, sized to the authored footprint,
/// with a ghost of the item: a faint grey silhouette of the real artwork, or a faded icon while there is no asset.
/// Hidden under the item once it sits there.
private struct TargetOutlineView: View {
    let item: TechItem
    let cellSize: CGFloat
    let isFilled: Bool

    var body: some View {
        let color = Theme.color(for: item.category)
        let art = ItemArt.resolve(for: item)
        let side = min(item.widthInGrid, item.heightInGrid)
        let inner = CGSize(width: CGFloat(item.widthInGrid) * cellSize * 0.88, height: CGFloat(item.heightInGrid) * cellSize * 0.88)
        RoundedRectangle(cornerRadius: cellSize * 0.22, style: .continuous)
            .fill(color.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: cellSize * 0.22, style: .continuous)
                    .strokeBorder(color.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .overlay {
                if art.isAsset {
                    ItemArtworkView(art: art)
                        .frame(width: inner.width, height: inner.height)
                        .grayscale(1)
                        .opacity(0.22)
                } else {
                    ItemArtworkView(art: art, symbolTint: color.opacity(0.5))
                        .opacity(0.8)
                        .frame(width: CGFloat(side) * cellSize * 0.45, height: CGFloat(side) * cellSize * 0.45)
                }
            }
            .padding(max(2, cellSize * 0.06))
            .frame(width: CGFloat(item.widthInGrid) * cellSize, height: CGFloat(item.heightInGrid) * cellSize)
            .opacity(isFilled ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: isFilled)
            .accessibilityHidden(true)
    }
}

/// Tints individual desk cells (same rounded-slot shape as the empty grid spots). Non-interactive.
private struct CellHighlightLayer: View {
    let cells: [GridPoint]
    let color: Color
    let strength: Double
    let cellSize: CGFloat

    var body: some View {
        ForEach(cells, id: \.self) { cell in
            RoundedRectangle(cornerRadius: cellSize * 0.18, style: .continuous)
                .fill(color.opacity(strength))
                .padding(cellSize * 0.07)
                .frame(width: cellSize, height: cellSize)
                .offset(x: CGFloat(cell.column) * cellSize, y: CGFloat(cell.row) * cellSize)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

/// Dashed outline of the whole footprint: green where the item will snap, red when it collides
/// or hangs over the desk edge (the part off the desk is still outlined, so overhang is visible).
struct SnapGhostView: View {
    let preview: HoverPreview
    let cellSize: CGFloat

    var body: some View {
        let color = preview.isValid ? Theme.valid : Theme.invalid
        RoundedRectangle(cornerRadius: cellSize * 0.22, style: .continuous)
            .fill(color.opacity(0.06)) // cells are tinted by CellHighlightLayer; this is just the outline
            .overlay {
                RoundedRectangle(cornerRadius: cellSize * 0.22, style: .continuous)
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
            }
            .padding(cellSize * 0.04)
            .frame(width: CGFloat(preview.size.width) * cellSize, height: CGFloat(preview.size.height) * cellSize)
    }
}
