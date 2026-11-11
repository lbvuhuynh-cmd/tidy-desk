import SwiftUI

/// An item tile that can be picked up. Used both on the desk and in the drawer.
///
/// * **Drag** starts after `DeskDragViewModel.dragThreshold` points of movement, so a plain tap stays a tap.
/// * **Tap** (drawer only) rotates the item 90°, with a springy quarter-turn.
///
/// While it is being dragged it stays in place, dimmed, as a "where it came from" marker
/// (keeping the view alive also keeps the gesture alive).
struct DraggableItemView: View {
    let item: TechItem
    let vm: DeskDragViewModel
    let cellSize: CGFloat

    @GestureState private var isTouching = false

    private var canRotate: Bool { !item.isPlaced }

    var body: some View {
        let isSource = vm.session?.itemID == item.id

        ItemTileView(item: item, cellSize: cellSize)
            .overlay(alignment: .topTrailing) {
                if canRotate && !item.isSquare { RotateBadge(size: max(14, cellSize * 0.42)) }
            }
            // Quarter-turn: the footprint swaps instantly, the picture starts at -90° (= old orientation)
            // and springs to 0°, so it reads as the item physically turning.
            .keyframeAnimator(initialValue: 0.0, trigger: vm.rotationCounts[item.id, default: 0]) { content, angle in
                content.rotationEffect(.degrees(angle))
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-90.0, duration: 0.001)
                    SpringKeyframe(0.0, duration: 0.4, spring: .bouncy)
                }
            }
            .opacity(isSource ? 0.22 : 1)
            .saturation(isSource ? 0 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canRotate else { return }
                vm.rotate(item.id)
            }
            .gesture(
                DragGesture(minimumDistance: DeskDragViewModel.dragThreshold, coordinateSpace: .named(GameSpace.name))
                    .updating($isTouching) { _, state, _ in state = true }
                    .onChanged { value in
                        vm.dragChanged(itemID: item.id, startLocation: value.startLocation, location: value.location)
                    }
                    .onEnded { _ in vm.dragEnded(itemID: item.id) }
            )
            .onChange(of: isTouching) { _, touching in
                guard !touching else { return }
                // GestureState also resets on cancellation, where onEnded never fires.
                // Give a normal onEnded a moment to run first; dragCancelled is a no-op if it did.
                let id = item.id
                let vm = vm
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    vm.dragCancelled(itemID: id)
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text(canRotate ? "Drag onto the desk. Double-tap to rotate." : "Drag to move."))
            .accessibilityAction(named: Text("Rotate")) {
                if canRotate { vm.rotate(item.id) }
            }
    }
}

/// Small "you can turn me" hint on drawer items.
private struct RotateBadge: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(.black.opacity(0.28)))
            .offset(x: size * 0.15, y: -size * 0.15)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
