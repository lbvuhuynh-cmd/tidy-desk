import SwiftUI

/// The accessory drawer at the bottom: items not yet on the desk (drawn smaller than desk scale).
struct AccessoryDrawerView: View {
    let vm: DeskDragViewModel
    let cellSize: CGFloat

    var body: some View {
        let items = vm.drawerItems

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Accessory drawer", systemImage: "archivebox.fill")
                        .font(.subheadline.weight(.semibold))
                    if !items.isEmpty {
                        Text("Tap an item to rotate it")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(items.isEmpty ? "Empty" : "\(items.count) left")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            ZStack(alignment: .topLeading) {
                if items.isEmpty {
                    Label("Everything has a home", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
                FlowLayout(spacing: 12) {
                    ForEach(items) { item in
                        DraggableItemView(item: item, vm: vm, cellSize: cellSize)
                            .reportFrame(FrameKey.drawerItem(item.id))
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: cellSize * 3, alignment: .topLeading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.drawerInset))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.drawer)
                .overlay(alignment: .top) {
                    // Drawer handle.
                    Capsule().fill(.secondary.opacity(0.35)).frame(width: 44, height: 5).padding(.top, 6)
                }
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        }
        .reportFrame(FrameKey.drawer)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: items.map(\.id))
    }
}
