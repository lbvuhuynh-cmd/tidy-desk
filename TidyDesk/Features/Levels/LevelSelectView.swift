import SwiftUI
import SwiftData

/// Home screen: a cozy grid of desk cards, one per level file found by `LevelManager`.
///
/// * **State** comes live from SwiftData (`@Query LevelProgress`) through `LevelManager.status(of:progress:)`:
///   level 1 is always open, each next level opens when the previous one is cleared, cleared levels show their
///   best stars (1–3, from moves; see `StarRating`) and a check mark.
/// * **Navigation**: a `NavigationStack` with a typed path. Tapping an open card pushes `DeskGameplayView`
///   (standard push transition, back button in the game header). "Continue" jumps to the next level to play.
/// * **Juice**: cards press down, locked cards shake + buzz and explain what to clear first, and a card that
///   just got unlocked plays a small "lock pops open" animation when you come back to the menu.
struct LevelSelectView: View {
    @Environment(LevelManager.self) private var levelManager
    @Query private var progress: [LevelProgress]
    @Query(sort: \BabyProfile.createdAt) private var babies: [BabyProfile]
    @State private var showNursery = false

    @State private var path: [LevelRoute] = []
    /// Per-card shake counters (locked taps).
    @State private var shakes: [Int: Int] = [:]
    @State private var lockedHint: String?
    @State private var hintTask: Task<Void, Never>?
    /// Levels that became unlocked since the menu was last seen (they play the unlock animation once).
    @State private var justUnlocked: Set<Int> = []
    /// Levels whose unlock the player has already seen, persisted so the animation plays once per level.
    @AppStorage("levelSelect.seenUnlocked") private var seenUnlockedRaw = ""
    /// DEBUG `-openLevel` handled already (see onAppear).
    @State private var didOpenDebugLevel = false

    private let columns = [GridItem(.adaptive(minimum: 152), spacing: 14)]

    /// Navigation value: the JSON `levelId`.
    struct LevelRoute: Hashable { let levelId: Int }

    private var completedIds: Set<Int> { Set(progress.filter(\.isCompleted).map(\.levelId)) }
    private var earnedStars: Int {
        levelManager.availableLevels.reduce(0) { total, level in
            if case .completed(let stars) = levelManager.status(of: level.levelId, progress: progress) { return total + stars }
            return total
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        Button { showNursery = true } label: { BabyBannerView(profile: babies.first) }
                            .buttonStyle(PressableCardStyle())
                        if !levelManager.availableLevels.isEmpty {
                            ProgressSummaryView(cleared: completedIds.intersection(Set(levelManager.availableLevels.map(\.levelId))).count,
                                                total: levelManager.availableLevels.count,
                                                stars: earnedStars, maxStars: levelManager.maxStars)
                            continueButton
                        }
                        grid
                        emptyAndIssues
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                // Frosted strip behind the status bar / Dynamic Island so scrolled cards don't run under the clock.
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: 0)
                        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .top)
                }
                .onAppear {
                    if let id = levelManager.continueLevelId(completedIds: completedIds) {
                        scroller.scrollTo(id, anchor: .center)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .overlay(alignment: .bottom) { hintToast }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showNursery) { BabyNurseryView() }
            .navigationDestination(for: LevelRoute.self) { route in
                if let level = levelManager.level(id: route.levelId) {
                    DeskGameplayView(level: level)
                } else {
                    ContentUnavailableView("Level not found", systemImage: "questionmark.folder")
                }
            }
        }
        .tint(Theme.accent)
        .onAppear {
            detectNewUnlocks(animated: false)
            #if DEBUG
            // Screenshot helper (MAC_BUILD.md): launching with `-openLevel <id>` jumps straight into that level,
            // ignoring the lock. Launch arguments land in UserDefaults' argument domain.
            let debugLevel = UserDefaults.standard.integer(forKey: "openLevel")
            if debugLevel > 0, !didOpenDebugLevel, levelManager.level(id: debugLevel) != nil {
                didOpenDebugLevel = true   // only on launch, not every time the menu reappears
                path = [LevelRoute(levelId: debugLevel)]
            }
            // `-openNursery YES` opens Baby Corner (screenshots).
            if UserDefaults.standard.bool(forKey: "openNursery"), !didOpenDebugLevel {
                didOpenDebugLevel = true
                showNursery = true
            }
            #endif
        }
        // Back on the menu after playing: celebrate whatever got unlocked meanwhile.
        .onChange(of: path) { _, newPath in
            guard newPath.isEmpty else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350)) // let the pop transition finish
                detectNewUnlocks(animated: true)
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tidy Desk")
                .font(.largeTitle.bold())
            Text("Tech & Setup")
                .font(.title3)
                .foregroundStyle(.secondary)
            if levelManager.unlockAll {
                // TestFlight reminder: BetaConfig.unlockAllLevels is on.
                Label("Test build · all levels unlocked", systemImage: "lock.open.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var continueButton: some View {
        if let id = levelManager.continueLevelId(completedIds: completedIds), let level = levelManager.level(id: id) {
            let allDone = completedIds.count >= levelManager.availableLevels.count
            Button {
                open(level)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: allDone ? "arrow.counterclockwise" : "play.fill")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white.opacity(0.22)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(allDone ? "Replay" : "Continue")
                            .font(.caption.weight(.semibold))
                            .opacity(0.85)
                        Text("Level \(levelManager.displayNumber(of: id)) · \(level.levelName)")
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.subheadline.bold()).opacity(0.7)
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.accent.gradient))
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    /// Consecutive levels sharing a `chapter` (level JSON) form one section; numbering stays global (Level 1…N).
    private struct ChapterSection: Identifiable {
        struct Entry {
            let number: Int
            let level: LevelData
        }
        let title: String?
        var entries: [Entry]
        var id: Int { entries.first?.level.levelId ?? 0 }
    }

    private var sections: [ChapterSection] {
        var result: [ChapterSection] = []
        for (index, level) in levelManager.availableLevels.enumerated() {
            if let last = result.last, last.title == level.chapter {
                result[result.count - 1].entries.append(.init(number: index + 1, level: level))
            } else {
                result.append(ChapterSection(title: level.chapter, entries: [.init(number: index + 1, level: level)]))
            }
        }
        return result
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { chapterIndex, section in
                VStack(alignment: .leading, spacing: 12) {
                    if let title = section.title {
                        ChapterHeader(number: chapterIndex + 1, title: title,
                                      cleared: section.entries.filter { completedIds.contains($0.level.levelId) }.count,
                                      total: section.entries.count)
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(section.entries, id: \.level.levelId) { entry in
                            levelButton(number: entry.number, level: entry.level)
                        }
                    }
                }
            }
        }
    }

    private func levelButton(number: Int, level: LevelData) -> some View {
        let status = levelManager.status(of: level.levelId, progress: progress)
        return Button {
            status.isPlayable ? open(level) : rejectLocked(level)
        } label: {
            LevelCard(number: number,
                      level: level,
                      status: status,
                      bestTime: progress.first { $0.levelId == level.levelId }?.bestTime,
                      isJustUnlocked: justUnlocked.contains(level.levelId))
        }
        .buttonStyle(PressableCardStyle())
        .modifier(ShakeEffect(shakes: CGFloat(shakes[level.levelId, default: 0])))
        .id(level.levelId)
    }

    @ViewBuilder
    private var emptyAndIssues: some View {
        if levelManager.availableLevels.isEmpty {
            ContentUnavailableView("No levels found", systemImage: "tray",
                                   description: Text("Add level_1.json … to TidyDesk/Resources/Levels."))
        }
        #if DEBUG
        if !levelManager.loadIssues.isEmpty {
            LoadIssuesView(issues: levelManager.loadIssues)
        }
        #endif
    }

    @ViewBuilder
    private var hintToast: some View {
        if let lockedHint {
            Label(lockedHint, systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.card).shadow(color: .black.opacity(0.15), radius: 12, y: 4))
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func open(_ level: LevelData) {
        HapticManager.shared.playLightImpact()
        path.append(LevelRoute(levelId: level.levelId))
    }

    private func rejectLocked(_ level: LevelData) {
        HapticManager.shared.playWarning()
        withAnimation(.linear(duration: 0.4)) { shakes[level.levelId, default: 0] += 1 }
        let previous = levelManager.prerequisite(of: level.levelId)
        let number = previous.map { levelManager.displayNumber(of: $0.levelId) } ?? 1
        hintTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            lockedHint = "Finish Level \(number) to unlock"
        }
        hintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { lockedHint = nil }
        }
    }

    /// Compares open levels with the ones already seen; new ones play the unlock animation once.
    /// First launch (nothing seen yet) just records the state silently.
    private func detectNewUnlocks(animated: Bool) {
        let open = Set(levelManager.availableLevels
            .filter { levelManager.status(of: $0.levelId, progress: progress).isPlayable }
            .map(\.levelId))
        let seen = Set(seenUnlockedRaw.split(separator: ",").compactMap { Int($0) })
        let fresh = open.subtracting(seen)
        seenUnlockedRaw = open.union(seen).sorted().map(String.init).joined(separator: ",")
        guard animated, !seen.isEmpty, !fresh.isEmpty else { return }
        justUnlocked = fresh
        HapticManager.shared.playSuccess()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.3)) { justUnlocked.subtract(fresh) }
        }
    }
}

// MARK: - Cards

/// Section title above a chapter's cards: "Chapter 4 · Garden Corner" with a small icon and "3/10".
private struct ChapterHeader: View {
    let number: Int
    let title: String
    let cleared: Int
    let total: Int

    /// Icon by chapter title keyword; unknown titles get a generic one (chapters live in the level JSON).
    private var icon: String {
        let t = title.lowercased()
        if t.contains("garden") || t.contains("plant") { return "leaf.fill" }
        if t.contains("gaming") || t.contains("game") { return "gamecontroller.fill" }
        if t.contains("office") || t.contains("work") { return "briefcase.fill" }
        if t.contains("first") || t.contains("start") { return "sparkles" }
        return "square.grid.2x2.fill"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.accent.opacity(0.14)))
            VStack(alignment: .leading, spacing: 0) {
                Text("Chapter \(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(title)
                    .font(.title3.bold())
            }
            Spacer()
            Text("\(cleared)/\(total)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(cleared == total ? Theme.accent : .secondary)
            if cleared == total {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct LevelCard: View {
    let number: Int
    let level: LevelData
    let status: LevelManager.LevelStatus
    let bestTime: Double?
    let isJustUnlocked: Bool

    private var isLocked: Bool { status == .locked }
    private var stars: Int {
        if case .completed(let stars) = status { return stars }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Level \(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                badge
            }

            MiniBoard(level: level, isLocked: isLocked)
                .frame(height: 64)
                .overlay {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .background(Circle().fill(Theme.card.opacity(0.85)))
                    }
                }
                .overlay { if isJustUnlocked { UnlockBurst() } }

            Text(level.levelName)
                .font(.headline)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.85)
                .foregroundStyle(isLocked ? .secondary : .primary)

            footer
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isLocked ? Theme.drawer : Theme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isJustUnlocked ? Theme.accent : .clear, lineWidth: 2)
                }
                .shadow(color: .black.opacity(isLocked ? 0 : 0.06), radius: 8, y: 3)
        }
        .opacity(isLocked ? 0.7 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(isLocked ? [] : .isButton)
    }

    @ViewBuilder
    private var badge: some View {
        switch status {
        case .locked:
            EmptyView()
        case .unlocked:
            Text(isJustUnlocked ? "NEW" : "PLAY")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.accent.opacity(0.14)))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
                .font(.headline)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 3) {
            if case .completed = status {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < stars ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(i < stars ? Theme.star : Color.secondary.opacity(0.4))
                }
                Spacer(minLength: 4)
                if let bestTime {
                    Label(ScoreCalculator.formatTime(bestTime), systemImage: "timer")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
            } else {
                Text("\(level.gridCols)×\(level.gridRows) · \(level.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 16)
    }

    private var accessibilityText: String {
        switch status {
        case .locked: "Level \(number), \(level.levelName), locked"
        case .unlocked: "Level \(number), \(level.levelName), not played yet"
        case .completed(let stars): "Level \(number), \(level.levelName), completed with \(stars) of 3 stars"
        }
    }
}

/// Tiny preview of the desk: its grid shape, with the messy starting items drawn in their category colours.
private struct MiniBoard: View {
    let level: LevelData
    let isLocked: Bool

    var body: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width / CGFloat(level.gridCols), geo.size.height / CGFloat(level.gridRows))
            let width = cell * CGFloat(level.gridCols), height = cell * CGFloat(level.gridRows)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cell * 0.35, style: .continuous)
                    .fill(Theme.desk)
                ForEach(0..<(level.gridRows * level.gridCols), id: \.self) { index in
                    RoundedRectangle(cornerRadius: cell * 0.2)
                        .fill(Theme.slot)
                        .padding(cell * 0.1)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(index % level.gridCols) * cell, y: CGFloat(index / level.gridCols) * cell)
                }
                ForEach(level.items.filter { $0.initialPosition != nil }, id: \.id) { item in
                    if let p = item.initialPosition {
                        RoundedRectangle(cornerRadius: cell * 0.25, style: .continuous)
                            .fill(Theme.color(for: item.category ?? .peripheral))
                            .padding(cell * 0.08)
                            .frame(width: cell * CGFloat(item.gridWidth), height: cell * CGFloat(item.gridHeight))
                            .offset(x: CGFloat(p.column) * cell, y: CGFloat(p.row) * cell)
                    }
                }
            }
            .frame(width: width, height: height)
            .blur(radius: isLocked ? 2.5 : 0)
            .saturation(isLocked ? 0 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// One-shot "lock pops open" effect for a freshly unlocked card.
private struct UnlockBurst: View {
    @State private var phase = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.accent, lineWidth: 3)
                .scaleEffect(phase ? 1.8 : 0.4)
                .opacity(phase ? 0 : 0.9)
            Image(systemName: phase ? "lock.open.fill" : "lock.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .padding(12)
                .background(Circle().fill(Theme.card))
                .scaleEffect(phase ? 1.25 : 1)
                .opacity(phase ? 0 : 1)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 60, height: 60)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) { phase = true }
        }
    }
}

/// Header card: desks cleared + stars collected, with a progress bar.
private struct ProgressSummaryView: View {
    let cleared: Int
    let total: Int
    let stars: Int
    let maxStars: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(cleared) / \(total) desks", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
                Spacer()
                Label("\(stars) / \(maxStars)", systemImage: "star.fill")
                    .foregroundStyle(Theme.star)
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())
            ProgressView(value: Double(cleared), total: Double(max(total, 1)))
                .tint(Theme.accent)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Interaction helpers

/// Cards sink a little under the finger.
private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Horizontal "nope" shake; animate `shakes` from n to n + 1.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(shakes * .pi * 6), y: 0))
    }
}

#if DEBUG
/// Developer aid: level files that were skipped, and why (only in Debug builds).
private struct LoadIssuesView: View {
    let issues: [LevelManager.LoadIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Level file problems (Debug only)", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.invalid)
            ForEach(issues) { issue in
                Text("\(issue.file): \(issue.message)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }
}
#endif

#Preview {
    LevelSelectView()
        .environment(LevelManager())
        .modelContainer(for: [LevelProgress.self, BabyProfile.self], inMemory: true)
}
