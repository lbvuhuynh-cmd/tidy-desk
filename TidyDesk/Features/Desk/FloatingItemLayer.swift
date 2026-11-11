import SwiftUI

/// Full-screen, non-interactive layer that draws the item under the finger at desk scale.
struct FloatingItemLayer: View {
    let vm: DeskDragViewModel

    var body: some View {
        ZStack {
            if let session = vm.session, let item = vm.findItem(session.itemID) {
                FloatingTile(item: item,
                             cellSize: vm.cellSize,
                             startScale: session.source == .drawer ? vm.drawerCellSize / vm.cellSize : 1,
                             settle: vm.settle,
                             isWarning: vm.hover?.isValid == false)
                    .scaleEffect(vm.floatingScale)
                    .position(vm.floatingCenter)
                    .id(item.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

/// Elevation & lift-off:
/// * appears at its resting size (drawer scale or desk scale), then springs up to `liftScale` (1.08×, drawn
///   natively at that size so vector art stays sharp),
///   tilts a little, turns slightly see-through and casts a deep shadow;
/// * when landing in a cell, elevation drops back to 0 together with the view model's landing spring,
///   so the shadow "collapses" exactly as the item touches the desk.
private struct FloatingTile: View {
    let item: TechItem
    let cellSize: CGFloat
    let startScale: CGFloat
    let settle: SettleKind?
    let isWarning: Bool

    @State private var lifted = false

    private var elevation: CGFloat {
        guard lifted else { return 0 }
        switch settle {
        case .landing: return 0
        case .bouncingBack: return 0.45
        case nil: return 1
        }
    }

    var body: some View {
        // Crisp lift-off: the tile is laid out (and its vector art rendered) at the *lifted* size, and only ever
        // scaled DOWN from there: 1.0 when lifted, smaller at rest / in the drawer. Scaling a rendered layer up
        // by 1.08 would soften the artwork; scaling down keeps it sharp. Visible sizes are unchanged.
        let lift = DeskDragViewModel.liftScale
        ItemTileView(item: item, cellSize: cellSize * lift, elevation: elevation, isWarning: isWarning)
            .opacity(lifted && settle == nil ? DeskDragViewModel.liftOpacity : 1)
            .scaleEffect(lifted ? 1 : startScale / lift)
            .rotationEffect(.degrees(lifted && settle == nil ? -2 : 0))
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: settle)
            .onAppear {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) { lifted = true }
            }
    }
}
