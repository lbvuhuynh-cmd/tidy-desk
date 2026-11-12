import SwiftUI
import SwiftData

/// MVP play screen: header, desk surface on top, accessory drawer below, floating drag layer,
/// "Setup Complete" overlay.
///
/// Fully data-driven: the desk size, the items, their messy starting spots and any fixed targets all come from
/// the `LevelData` handed in (decoded from `level_<n>.json` by `LevelManager`). "Next desk" asks the
/// `LevelManager` in the environment for the following level.
struct DeskGameplayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LevelManager.self) private var levelManager

    @AppStorage(SettingsKeys.soundEnabled) private var soundEnabled = true
    @AppStorage(SettingsKeys.hapticsEnabled) private var hapticsEnabled = true

    @State private var vm: DeskDragViewModel
    @State private var showClear = false
    @State private var isNewBest = false
    @State private var confirmLeave = false
    /// Baby Corner payout for the clear on screen.
    @State private var babyReward: BabyReward?
    private let babyFeedback: BabyFeedback

    init(level: LevelData, feedback: GameFeedback? = nil) {
        let feedback = feedback ?? FeedbackEngine.shared
        _vm = State(initialValue: DeskDragViewModel(level: level, feedback: feedback))
        babyFeedback = (feedback as? BabyFeedback) ?? FeedbackEngine.shared
    }

    private var nextLevel: LevelData? { levelManager.nextLevel(after: vm.level.levelId) }

    var body: some View {
        GeometryReader { geo in
            let cell = Self.cellSize(for: vm.level, in: geo.size)
            let drawerCell = Self.drawerCellSize(boardCell: cell)

            ZStack {
                VStack(spacing: 12) {
                    header
                    Spacer(minLength: 4)
                    DeskSurfaceView(vm: vm, cellSize: cell)
                    Spacer(minLength: 4)
                    AccessoryDrawerView(vm: vm, cellSize: drawerCell)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                FloatingItemLayer(vm: vm)

                if showClear {
                    SetupCompleteView(title: vm.level.levelName,
                                   seconds: vm.elapsed(),
                                   moves: vm.moves,
                                   score: vm.score,
                                   stars: vm.stars,
                                   isNewBest: isNewBest,
                                   babyReward: babyReward,
                                   hasNextLevel: nextLevel != nil,
                                   onNext: goToNextLevel,
                                   onReplay: replay,
                                   onLevels: { dismiss() })
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .coordinateSpace(.named(GameSpace.name))
            .onPreferenceChange(FramePreferenceKey.self) { frames in
                MainActor.assumeIsolated { vm.frames = frames }
            }
            .onChange(of: cell, initial: true) { _, value in vm.cellSize = value }
            .onChange(of: drawerCell, initial: true) { _, value in vm.drawerCellSize = value }
        }
        .background {
            // The "after" moment: warm light blooms behind the finished desk, like the room's lamps just came on.
            ZStack {
                Theme.background
                RadialGradient(colors: [ItemLifeView.warm.opacity(0.55), ItemLifeView.warm.opacity(0)],
                               center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 520)
                    .opacity(vm.isLevelClear ? 1 : 0)
                    .animation(.easeInOut(duration: 1.2), value: vm.isLevelClear)
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            levelManager.loadLevel(id: vm.level.levelId)
            // Warm up audio + Taptic Engine before the first touch on this desk.
            SoundManager.shared.preload()
            HapticManager.shared.prepare()
        }
        .onChange(of: vm.isLevelClear) { _, cleared in
            guard cleared else { return }
            let isFirstClear = !ProgressStore.isCompleted(levelId: vm.level.levelId, in: modelContext)
            isNewBest = ProgressStore.recordClear(levelId: vm.level.levelId, moves: vm.moves, stars: vm.stars,
                                                  seconds: vm.elapsed(), score: vm.score, in: modelContext)
            // Baby Corner: coins + growth for the baby (shown on the card, chime when it appears).
            babyReward = BabyStore.rewardClear(stars: vm.stars, isFirstClear: isFirstClear, in: modelContext)
            vm.feedback.lightsOn()
            Task { @MainActor in
                // Let the last snap land, the light sweep and LED wave run across the devices, and give the
                // player a beat to enjoy the tidy desk before the card covers it.
                try? await Task.sleep(for: .milliseconds(1500))
                guard vm.isLevelClear else { return }
                vm.feedback.levelCleared()
                withAnimation(.easeOut(duration: 0.25)) { showClear = true }
                // Coin chime once the reward row pops in on the card (after the stars).
                try? await Task.sleep(for: .milliseconds(1100))
                guard showClear, babyReward != nil else { return }
                babyFeedback.coinsEarned()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: leave) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
            }
            .accessibilityLabel(Text("Back to levels"))
            .confirmationDialog("Leave this desk?", isPresented: $confirmLeave, titleVisibility: .visible) {
                Button("Leave", role: .destructive) { dismiss() }
                Button("Keep tidying", role: .cancel) {}
            } message: {
                Text("Your progress on this desk will be reset.")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Level \(levelManager.displayNumber(of: vm.level.levelId))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                // Long names ("Streamer Corner", "Gaming Battlestation") wrap to a second line
                // instead of truncating next to the clock / moves / menu pills.
                Text(vm.level.levelName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer()

            // Live clock: starts on the first touch, freezes when the desk is complete.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(ScoreCalculator.formatTime(vm.elapsed(at: context.date)), systemImage: "timer")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.card))
                    .fixedSize()  // never squeezed by the (higher-priority) title
            }
            .accessibilityLabel(Text("Time"))

            Label("\(vm.moves)", systemImage: "hand.draw.fill")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())
                .animation(.snappy, value: vm.moves)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.card))
                .fixedSize()
                .accessibilityLabel(Text("\(vm.moves) moves"))

            Menu {
                Button(action: replay) { Label("Reset desk", systemImage: "arrow.counterclockwise") }
                Toggle(isOn: $soundEnabled) { Label("Sound", systemImage: "speaker.wave.2.fill") }
                Toggle(isOn: $hapticsEnabled) { Label("Haptics", systemImage: "iphone.radiowaves.left.and.right") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
            }
            .accessibilityLabel(Text("Options"))
        }
        .foregroundStyle(.primary)
        .padding(.top, 4)
    }

    // MARK: Actions

    /// Back to the level menu. Mid-level (something placed, not cleared) asks first, because progress isn't saved.
    private func leave() {
        if vm.moves > 0 && !vm.isLevelClear {
            confirmLeave = true
        } else {
            dismiss()
        }
    }

    private func replay() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showClear = false
            babyReward = nil
            vm.restart()
        }
    }

    private func goToNextLevel() {
        // The level was just cleared and saved, so the next one is unlocked by definition.
        guard let next = nextLevel, let level = levelManager.loadLevel(id: next.levelId) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            showClear = false
            babyReward = nil
            vm.load(level)
        }
    }

    // MARK: Layout

    /// Biggest cell that fits the desk in the width and about half the height, capped for iPad.
    /// Works for any `gridRows × gridCols` from the level file (8 columns ≈ 42 pt cells on a 6.1" iPhone).
    static func cellSize(for level: LevelData, in size: CGSize) -> CGFloat {
        let boardChrome: CGFloat = 0.44 // padding around the grid = 2 * 0.22 cell
        let byWidth = (size.width - 32) / (CGFloat(level.gridCols) + boardChrome)
        let byHeight = (size.height * 0.52) / (CGFloat(level.gridRows) + boardChrome)
        return max(24, floor(min(byWidth, byHeight, 84)))
    }

    static func drawerCellSize(boardCell: CGFloat) -> CGFloat {
        floor(min(boardCell * 0.6, 34))
    }
}

#Preview {
    let manager = LevelManager()
    return Group {
        if let level = manager.availableLevels.first(where: { $0.hasFixedTargets }) ?? manager.availableLevels.first {
            DeskGameplayView(level: level, feedback: SilentFeedback())
        } else {
            Text("No levels in bundle")
        }
    }
    .environment(manager)
    .modelContainer(for: [LevelProgress.self, BabyProfile.self], inMemory: true)
}
