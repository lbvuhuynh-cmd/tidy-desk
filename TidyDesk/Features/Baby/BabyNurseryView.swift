import SwiftUI
import SwiftData

/// Baby Corner: the baby's room. Coins earned by tidying desks buy milk and snacks, toys and outfits;
/// bath time and lullabies are free. The baby grows month by month (`BabyGrowth`), reaching milestones that
/// become pages in the Baby Book.
///
/// Built for young players too: big emoji buttons, short words, nothing ever goes wrong. When the baby is full or
/// coins run short, a friendly note says to tidy a desk; tapping the baby (giggles + hearts) is always free.
/// Rules: `BabyState`. Sounds + haptics: `BabyFeedback` (→ `FeedbackEngine`).
struct BabyNurseryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \BabyProfile.createdAt) private var profiles: [BabyProfile]

    /// `nil` = `FeedbackEngine.shared` (resolved on the main actor; tests and previews pass `SilentFeedback`).
    var feedback: BabyFeedback?

    private var fx: BabyFeedback { feedback ?? FeedbackEngine.shared }

    enum CareTab: CaseIterable {
        case feed, play, bath, sleep, dress

        var title: String {
            switch self {
            case .feed: "Feed"
            case .play: "Play"
            case .bath: "Bath"
            case .sleep: "Sleep"
            case .dress: "Dress"
            }
        }

        var emoji: String {
            switch self {
            case .feed: "🍼"
            case .play: "🧸"
            case .bath: "🛁"
            case .sleep: "🌙"
            case .dress: "👕"
            }
        }

        /// Shop shelf for this tab; bath and sleep are free activities instead.
        var kind: BabyShopItem.Kind? {
            switch self {
            case .feed: .food
            case .play: .toy
            case .dress: .outfit
            case .bath, .sleep: nil
            }
        }
    }

    /// What the room is showing: the normal nursery, bath time, or the cradle at night.
    enum RoomMode: Equatable { case normal, bath, sleep }

    private struct FloatingBit: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
    }

    private struct Bubble: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
    }

    /// A growth moment to celebrate: a new stage and/or new Baby Book pages.
    struct Celebration: Identifiable {
        let id = UUID()
        let stage: BabyStage?
        let milestones: [BabyMilestone]
    }

    @State private var tab: CareTab = .feed
    @State private var mode: RoomMode = .normal
    @State private var mood: BabyAvatarView.Mood = .content
    @State private var moodTask: Task<Void, Never>?
    @State private var bounce = 0
    @State private var bits: [FloatingBit] = []
    @State private var note: String?
    @State private var noteTask: Task<Void, Never>?
    @State private var celebration: Celebration?
    @State private var showNaming = false
    @State private var didAskName = false
    @State private var showBook = false
    // Bath
    @State private var bubbles: [Bubble] = []
    // Sleep
    @State private var rockAngle = 0.0
    @State private var rockProgress = 0.0
    @State private var rockTask: Task<Void, Never>?
    @State private var isAsleep = false

    /// How long the player holds the baby to rock it to sleep.
    private static let rockDuration = 2.4

    var body: some View {
        Group {
            if let profile = profiles.first {
                content(profile)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            let profile = BabyStore.profile(in: modelContext)
            #if DEBUG
            // Screenshot helper (MAC_BUILD.md): `-babyName Bean` names the baby so the naming sheet is skipped.
            if profile.name.isEmpty, let debugName = UserDefaults.standard.string(forKey: "babyName"), !debugName.isEmpty {
                profile.name = debugName
                try? modelContext.save()
            }
            // `-babyMonths 8` sets the age (once per launch), `-openBabyBook YES` opens the Baby Book.
            let debugMonths = UserDefaults.standard.integer(forKey: "babyMonths")
            if debugMonths > 0, profile.state.months != debugMonths {
                profile.update { $0.setAgeForTesting(months: debugMonths) }
                try? modelContext.save()
            }
            if UserDefaults.standard.bool(forKey: "openBabyBook") {
                showBook = true
            }
            #endif
            if profile.name.isEmpty && !didAskName {
                didAskName = true
                showNaming = true
            }
        }
        .sheet(isPresented: $showNaming) {
            if let profile = profiles.first {
                BabyNamingSheet(initialName: profile.name) { name in
                    profile.name = name
                    try? modelContext.save()
                    react(with: "💗", count: 4)
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showBook) {
            if let profile = profiles.first {
                BabyBookView(state: profile.state, name: profile.displayName)
            }
        }
        .overlay {
            if let celebration, let profile = profiles.first {
                CelebrationCard(celebration: celebration,
                                state: profile.state,
                                name: profile.displayName,
                                onPickWord: { word in
                                    profile.update { (state: inout BabyState) -> Void in state.firstWord = word }
                                    try? modelContext.save()
                                },
                                onOpenBook: {
                                    withAnimation(.easeOut(duration: 0.2)) { self.celebration = nil }
                                    showBook = true
                                },
                                onClose: {
                                    withAnimation(.easeOut(duration: 0.2)) { self.celebration = nil }
                                })
                .transition(.opacity)
            }
        }
    }

    // MARK: Layout

    private func content(_ profile: BabyProfile) -> some View {
        let state = profile.state
        return VStack(spacing: 12) {
            topBar(state: state)
            nameRow(profile, state: state)
            room(profile, state: state)
            HStack(spacing: 8) {
                ForEach(BabyNeed.allCases, id: \.self) { need in
                    NeedMeter(need: need, value: state.value(of: need) / BabyState.maxNeed)
                }
            }
            tabPicker
            shelf(state: state, name: profile.displayName)
            if BetaConfig.unlockAllBabyContent {
                BetaBabyPanel(months: state.months,
                              onSetAge: { setAgeForTesting($0) },
                              onAddCoins: { addCoinsForTesting() },
                              onNeedCare: { lowerNeedsForTesting() })
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) { noteToast }
    }

    private func topBar(state: BabyState) -> some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
            }
            .accessibilityLabel(Text("Back to desks"))
            Text("Baby Corner")
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button { showBook = true } label: {
                Text("📖")
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
                    .overlay(alignment: .topTrailing) {
                        Text("\(state.reachedMilestones.count)")
                            .font(.caption2.weight(.heavy).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.accent))
                            .offset(x: 6, y: -4)
                    }
            }
            .accessibilityLabel(Text("Baby Book, \(state.reachedMilestones.count) pages"))
            CoinPill(coins: state.coins)
        }
        .foregroundStyle(.primary)
    }

    private func nameRow(_ profile: BabyProfile, state: BabyState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(profile.displayName)
                    .font(.headline)
                Button { showNaming = true } label: {
                    Image(systemName: "pencil.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("Rename baby"))
                Spacer()
                Text(BabyGrowth.ageText(months: state.months))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            GrowthBar(progress: state.monthProgress,
                      caption: state.months >= BabyGrowth.maxMonths
                        ? "🎉 \(state.stage.title) · 3 years old!"
                        : "🌱 \(state.stage.title) · growing to \(BabyGrowth.ageText(months: state.months + 1))")
        }
    }

    /// Room colors: warm pastel by day; at night (dark mode, or the lullaby) a cozy dusky nursery with
    /// moon and stars, so the room doesn't glare out of the dark UI.
    private var isNight: Bool { colorScheme == .dark || mode == .sleep }
    private var roomColors: [Color] {
        isNight
            ? [Color(red: 0.25, green: 0.23, blue: 0.36), Color(red: 0.19, green: 0.18, blue: 0.27)]
            : [Color(red: 1.0, green: 0.93, blue: 0.9), Color(red: 0.98, green: 0.95, blue: 0.86)]
    }
    private var rugColor: Color {
        isNight ? Color(red: 0.33, green: 0.38, blue: 0.53) : Color(red: 0.8, green: 0.88, blue: 0.95)
    }

    private func room(_ profile: BabyProfile, state: BabyState) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: roomColors, startPoint: .top, endPoint: .bottom))
                .animation(.easeInOut(duration: 0.6), value: isNight)
            if isNight {
                // Night sky: a little moon and a few stars (decoration only).
                Text("🌙")
                    .font(.system(size: 28))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(20)
                    .accessibilityHidden(true)
                ForEach(Array(Self.starSpots.enumerated()), id: \.offset) { _, spot in
                    Image(systemName: "sparkle")
                        .font(.system(size: spot.size))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, spot.x)
                        .padding(.top, spot.y)
                        .accessibilityHidden(true)
                }
            }
            // Play rug.
            Ellipse()
                .fill(rugColor)
                .frame(height: 70)
                .padding(.horizontal, 40)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)

            switch mode {
            case .normal: normalScene(state: state)
            case .bath: bathScene(state: state)
            case .sleep: sleepScene(state: state)
            }

            // What the baby would like (a gentle thought bubble, never crying).
            if mode == .normal, let wish = state.wish {
                Text(wish.emoji)
                    .font(.system(size: 26))
                    .padding(10)
                    .background(Circle().fill(.white).shadow(color: .black.opacity(0.1), radius: 4, y: 2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(18)
                    .accessibilityLabel(Text("\(profile.displayName) would like: \(wish.title)"))
            }

            if mode != .normal {
                activityChrome
            }

            ForEach(bits) { bit in
                FloatingEmoji(emoji: bit.emoji, x: bit.x, reduceMotion: reduceMotion)
            }
        }
        // Grows into spare screen height (tall phones), never below 220 pt (small phones).
        .frame(minHeight: 220, maxHeight: 330)
    }

    /// Fixed star positions (pt from the room's top-left) for the night room.
    private static let starSpots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (90, 30, 10), (150, 70, 7), (240, 24, 9), (300, 64, 12), (60, 110, 7), (320, 130, 8),
    ]

    private func normalScene(state: BabyState) -> some View {
        Button(action: tapBaby) {
            LivelyBabyView(stage: state.stage, outfit: state.equippedOutfit, mood: mood, size: 180,
                           drowsy: state.wantsSleep)
                .keyframeAnimator(initialValue: 1.0, trigger: bounce) { view, scale in
                    view.scaleEffect(scale, anchor: .bottom)
                } keyframes: { _ in
                    SpringKeyframe(reduceMotion ? 1.0 : 1.1, duration: 0.14)
                    SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
                }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Tap to cuddle"))
    }

    // MARK: Bath

    private func bathScene(state: BabyState) -> some View {
        ZStack {
            BabyAvatarView(stage: state.stage, outfit: nil, mood: .delighted, size: 160)
                .offset(y: -18)
            // Tub.
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.75, green: 0.88, blue: 0.98), Color(red: 0.55, green: 0.76, blue: 0.93)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .strokeBorder(.white.opacity(0.9), lineWidth: 5)
                )
                .frame(width: 250, height: 92)
                .offset(y: 64)
            Text("🦆").font(.system(size: 30)).offset(x: 88, y: 40)

            ForEach(bubbles) { bubble in
                Button { pop(bubble) } label: {
                    Circle()
                        .fill(.white.opacity(0.7))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .overlay(alignment: .topLeading) {
                            Circle().fill(.white).frame(width: bubble.size * 0.22).offset(x: bubble.size * 0.2, y: bubble.size * 0.18)
                        }
                        .shadow(color: Color(red: 0.4, green: 0.6, blue: 0.85).opacity(0.35), radius: 3)
                        .frame(width: bubble.size, height: bubble.size)
                }
                .buttonStyle(.plain)
                .offset(x: bubble.x, y: bubble.y)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
                .accessibilityLabel(Text("Bubble"))
                .accessibilityHint(Text("Tap to pop"))
            }
        }
    }

    // MARK: Sleep

    private func sleepScene(state: BabyState) -> some View {
        ZStack {
            BabyAvatarView(stage: state.stage, outfit: state.equippedOutfit, mood: isAsleep ? .asleep : .sleepy, size: 160)
                .offset(y: -14)
            // Cradle.
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 10, bottomLeading: 60, bottomTrailing: 60, topTrailing: 10),
                                   style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.86, green: 0.72, blue: 0.56), Color(red: 0.72, green: 0.56, blue: 0.42)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Capsule().fill(Color(red: 0.95, green: 0.88, blue: 0.95)).frame(height: 14).padding(.horizontal, 6).offset(y: -4)
                }
                .frame(width: 240, height: 78)
                .offset(y: 66)
        }
        .rotationEffect(.degrees(rockAngle), anchor: .bottom)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: Self.rockDuration, maximumDistance: 80) {
            finishSleep()
        } onPressingChanged: { pressing in
            if pressing { startRocking() } else { stopRocking() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isAsleep ? "Sleeping" : "Cradle"))
        .accessibilityAction(named: Text("Rock to sleep")) { finishSleep() }
    }

    /// Hint + progress + close button over the room during bath / sleep.
    private var activityChrome: some View {
        ZStack {
            Button {
                endActivity()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.85)))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(Text("Stop"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(14)

            VStack(spacing: 6) {
                if mode == .sleep && !isAsleep {
                    ProgressView(value: rockProgress)
                        .tint(Color(red: 0.75, green: 0.78, blue: 1.0))
                        .frame(width: 140)
                }
                Text(activityHint)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.85)))
                    .foregroundStyle(Color(red: 0.3, green: 0.25, blue: 0.35))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 14)
            .allowsHitTesting(false)
        }
    }

    private var activityHint: String {
        switch mode {
        case .bath: bubbles.isEmpty ? "Squeaky clean! ✨" : "Pop the bubbles! 🫧"
        case .sleep: isAsleep ? "Sweet dreams… 💤" : "Hold to rock the cradle 🌙"
        case .normal: ""
        }
    }

    // MARK: Tabs + shelf

    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(CareTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.snappy) { tab = item }
                } label: {
                    VStack(spacing: 1) {
                        Text(item.emoji).font(.system(size: 24))
                        Text(item.title).font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tab == item ? Theme.accent.opacity(0.18) : Theme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(tab == item ? Theme.accent : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func shelf(state: BabyState, name: String) -> some View {
        if let kind = tab.kind {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(BabyCatalog.items(of: kind)) { item in
                        Button { use(item) } label: {
                            ShopItemCard(item: item, state: state)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 16) // inset inside the scroll view...
            }
            .padding(.horizontal, -16) // ...which runs to the screen edges, so cards slide off the edge (clearly scrollable)
            .scrollIndicators(.hidden)
            .id(tab) // start each tab scrolled to the left
        } else if tab == .bath {
            CareActionCard(emoji: "🛁", title: "Bath time", subtitle: "Free · pop the bubbles!",
                           isActive: mode == .bath) { startBath() }
        } else {
            CareActionCard(emoji: "🌙", title: "Lullaby", subtitle: "Free · rock \(name) to sleep",
                           isActive: mode == .sleep) { startSleep() }
        }
    }

    @ViewBuilder
    private var noteToast: some View {
        if let note {
            Text(note)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.card).shadow(color: .black.opacity(0.15), radius: 12, y: 4))
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func tapBaby() {
        fx.babyTapped()
        react(with: "💗", count: 2)
    }

    /// Runs a care rule on the saved profile; returns its result and the Baby Book pages it unlocked.
    private func perform(_ change: (inout BabyState) -> CareResult) -> (result: CareResult, milestones: [BabyMilestone]) {
        guard let profile = profiles.first else { return (.invalid, []) }
        let before = Set(profile.state.milestoneDates.keys)
        let result = profile.update(change)
        try? modelContext.save()
        let fresh = profile.state.reachedMilestones.filter { !before.contains($0.id) }
        return (result, fresh)
    }

    private func use(_ item: BabyShopItem) {
        guard let profile = profiles.first else { return }
        if mode != .normal { endActivity() }
        let name = profile.displayName
        let outcome: (result: CareResult, milestones: [BabyMilestone])
        switch item.kind {
        case .food:
            outcome = perform { $0.feed(item) }
            if outcome.result.isDone { fx.babyFed() }
        case .toy:
            outcome = perform { (state: inout BabyState) -> CareResult in
                if !state.owns(item) {
                    let bought = state.buy(item)
                    guard bought.isDone else { return bought }
                }
                return state.play(with: item)
            }
            if outcome.result.isDone { fx.babyPlayed() }
        case .outfit:
            let wasOwned = profile.state.owns(item)
            outcome = perform { (state: inout BabyState) -> CareResult in
                if !state.owns(item) {
                    let bought = state.buy(item)
                    guard bought.isDone else { return bought }
                }
                return state.wear(item)
            }
            if outcome.result.isDone {
                if wasOwned { fx.outfitChanged() } else { fx.itemBought() }
            }
        }

        switch outcome.result {
        case .done(let grew):
            react(with: item.kind == .outfit ? "✨" : item.emoji, count: 1)
            if item.kind != .outfit { react(with: "💗", count: 1) }
            celebrate(stage: grew, milestones: outcome.milestones)
        case .notEnoughCoins(let missing):
            decline("Need \(missing) more 🪙. Tidy a desk to earn coins!")
        case .alreadyFull:
            decline(item.kind == .food ? "\(name) is full! 😊 Tidy a desk, then feed again."
                                       : "\(name) is all giggled out! 😊 Tidy a desk, then play again.")
        case .tooYoung(let needs):
            decline("For later! Unlocks when \(name) is a \(needs.title).")
        case .notOwned, .alreadyOwned, .invalid:
            break
        }
    }

    private func startBath() {
        guard let profile = profiles.first else { return }
        guard profile.state.clean < BabyState.maxNeed else {
            decline("\(profile.displayName) is already squeaky clean! ✨ Tidy a desk, then bath again.")
            return
        }
        endActivity()
        var made: [Bubble] = []
        // Spread 8 big, easy-to-tap bubbles around the tub.
        let spots: [(CGFloat, CGFloat)] = [(-105, 20), (-60, -60), (-15, 45), (40, -75), (95, -20), (110, 55), (-110, -45), (60, 30)]
        for (x, y) in spots {
            made.append(Bubble(x: x + .random(in: -10...10), y: y + .random(in: -10...10), size: .random(in: 44...60)))
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            mode = .bath
            bubbles = made
        }
    }

    private func pop(_ bubble: Bubble) {
        fx.bubblePopped()
        withAnimation(.easeOut(duration: 0.2)) { bubbles.removeAll { $0.id == bubble.id } }
        bits.append(FloatingBit(emoji: "🫧", x: bubble.x))
        let id = bits.last?.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            bits.removeAll { $0.id == id }
        }
        if bubbles.isEmpty { finishBath() }
    }

    private func finishBath() {
        let outcome = perform { $0.bathe() }
        if outcome.result.isDone {
            fx.babyBathed()
            react(with: "✨", count: 2)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.4)) { if mode == .bath { mode = .normal } }
            if case .done(let grew) = outcome.result { celebrate(stage: grew, milestones: outcome.milestones) }
        }
    }

    private func startSleep() {
        guard let profile = profiles.first else { return }
        guard profile.state.rest < BabyState.maxNeed else {
            decline("\(profile.displayName) isn't sleepy yet 😊 Tidy a desk, then come back.")
            return
        }
        endActivity()
        isAsleep = false
        rockProgress = 0
        withAnimation(.easeInOut(duration: 0.5)) { mode = .sleep }
    }

    private func startRocking() {
        guard mode == .sleep, !isAsleep else { return }
        rockTask?.cancel()
        if !reduceMotion {
            rockAngle = -5
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { rockAngle = 5 }
        }
        withAnimation(.linear(duration: Self.rockDuration)) { rockProgress = 1 }
        rockTask = Task { @MainActor in
            while !Task.isCancelled {
                fx.cradleRocked()
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }

    private func stopRocking() {
        rockTask?.cancel()
        rockTask = nil
        withAnimation(.easeOut(duration: 0.3)) {
            rockAngle = 0
            if !isAsleep { rockProgress = 0 }
        }
    }

    private func finishSleep() {
        guard mode == .sleep, !isAsleep else { return }
        stopRocking()
        let outcome = perform { $0.sleep() }
        guard outcome.result.isDone else {
            endActivity()
            return
        }
        fx.babyFellAsleep()
        withAnimation(.easeInOut(duration: 0.4)) {
            isAsleep = true
            rockProgress = 1
        }
        bits.append(FloatingBit(emoji: "💤", x: 40))
        let id = bits.last?.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2200))
            bits.removeAll { $0.id == id }
            withAnimation(.easeInOut(duration: 0.6)) {
                if mode == .sleep { mode = .normal }
                isAsleep = false
            }
            if case .done(let grew) = outcome.result { celebrate(stage: grew, milestones: outcome.milestones) }
        }
    }

    private func endActivity() {
        stopRocking()
        withAnimation(.easeInOut(duration: 0.3)) {
            mode = .normal
            bubbles = []
            isAsleep = false
            rockProgress = 0
        }
    }

    private func react(with emoji: String, count: Int) {
        mood = .delighted
        bounce += 1
        for i in 0..<count {
            let bit = FloatingBit(emoji: emoji, x: CGFloat.random(in: -70...70) + CGFloat(i) * 8)
            bits.append(bit)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1400))
                bits.removeAll { $0.id == bit.id }
            }
        }
        moodTask?.cancel()
        moodTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled else { return }
            mood = .content
        }
    }

    private func decline(_ message: String) {
        fx.careDeclined()
        noteTask?.cancel()
        withAnimation(.snappy) { note = message }
        noteTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut) { note = nil }
        }
    }

    private func celebrate(stage: BabyStage?, milestones: [BabyMilestone]) {
        guard stage != nil || !milestones.isEmpty else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if milestones.isEmpty { fx.babyGrew() } else { fx.milestoneReached() }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                celebration = Celebration(stage: stage, milestones: milestones)
            }
        }
    }

    // MARK: TestFlight helpers (BetaConfig.unlockAllBabyContent)

    private func setAgeForTesting(_ months: Int) {
        guard let profile = profiles.first else { return }
        endActivity()
        let before = profile.stage
        let fresh = profile.update { $0.setAgeForTesting(months: months) }
        try? modelContext.save()
        let after = profile.stage
        celebrate(stage: after > before ? after : nil, milestones: fresh)
    }

    private func addCoinsForTesting() {
        guard let profile = profiles.first else { return }
        profile.update { (state: inout BabyState) -> Void in state.coins += 100 }
        try? modelContext.save()
        fx.coinsEarned()
    }

    private func lowerNeedsForTesting() {
        guard let profile = profiles.first else { return }
        profile.update { (state: inout BabyState) -> Void in
            state.tummy = 30
            state.joy = 30
            state.clean = 30
            state.rest = 30
        }
        try? modelContext.save()
    }
}

// MARK: - Pieces

struct CoinPill: View {
    let coins: Int

    var body: some View {
        Label {
            Text("\(coins)")
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText(value: Double(coins)))
                .animation(.snappy, value: coins)
        } icon: {
            Text("🪙")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(coins) coins"))
    }
}

struct GrowthBar: View {
    let progress: Double
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accent.opacity(0.15))
                    Capsule().fill(Theme.accent.gradient)
                        .frame(width: max(8, geo.size.width * progress))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 10)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(caption), \(Int(progress * 100)) percent"))
    }
}

/// Icon-first need meter (no reading needed): emoji over a short bar.
private struct NeedMeter: View {
    let need: BabyNeed
    let value: Double

    private var color: Color {
        switch need {
        case .tummy: Color(red: 0.98, green: 0.72, blue: 0.45)
        case .joy: Color(red: 0.95, green: 0.55, blue: 0.68)
        case .clean: Color(red: 0.45, green: 0.72, blue: 0.92)
        case .rest: Color(red: 0.62, green: 0.58, blue: 0.9)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(need.emoji).font(.system(size: 20))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.2))
                    Capsule().fill(color)
                        .frame(width: max(6, geo.size.width * min(1, max(0, value))))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(need.title) \(Int(value * 100)) percent"))
    }
}

private struct ShopItemCard: View {
    let item: BabyShopItem
    let state: BabyState

    private var tooYoung: Bool { !state.isOldEnough(for: item) }
    private var owned: Bool { state.owns(item) }
    private var wearing: Bool { item.kind == .outfit && state.equippedOutfitId == item.id }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if item.kind == .outfit {
                    Circle().fill(Color(hex: item.color)).frame(width: 52, height: 52)
                }
                Text(item.emoji).font(.system(size: 34))
            }
            .frame(height: 54)
            .opacity(tooYoung ? 0.35 : 1)
            .overlay(alignment: .topTrailing) {
                if tooYoung { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
            }

            Text(item.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            footer
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(footerTint.opacity(0.15)))
                .foregroundStyle(footerTint)
        }
        .frame(width: 92)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(wearing ? Theme.accent : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var footer: some View {
        if tooYoung {
            Text(item.minStage.title)
        } else if wearing {
            Text("Wearing")
        } else if item.kind != .food && owned {
            Text(item.kind == .toy ? "Play" : "Wear")
        } else {
            Text("🪙 \(item.price)")
        }
    }

    private var footerTint: Color {
        if tooYoung { return .secondary }
        if item.kind != .food && owned { return Theme.accent }
        return state.coins >= item.price ? Color.orange : .secondary
    }
}

/// Big free-activity button for the Bath and Sleep tabs.
private struct CareActionCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 44))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isActive ? "arrow.counterclockwise" : "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.accent))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title). \(subtitle)"))
    }
}

/// TestFlight-only controls (`BetaConfig.unlockAllBabyContent`): jump the age, add coins, make the baby need care.
private struct BetaBabyPanel: View {
    let months: Int
    let onSetAge: (Int) -> Void
    let onAddCoins: () -> Void
    let onNeedCare: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("🧪").font(.caption)
            Button { onSetAge(months - 1) } label: { Image(systemName: "minus") }
                .disabled(months <= 0)
            Menu {
                ForEach(BabyStage.allCases, id: \.self) { stage in
                    Button("\(stage.title) (\(stage.startMonth) mo)") { onSetAge(stage.startMonth) }
                }
                Button("3 years (36 mo)") { onSetAge(BabyGrowth.maxMonths) }
            } label: {
                Text("\(months) mo")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .frame(minWidth: 44)
            }
            Button { onSetAge(months + 1) } label: { Image(systemName: "plus") }
                .disabled(months >= BabyGrowth.maxMonths)
            Spacer(minLength: 4)
            Button("+100 🪙", action: onAddCoins)
            Button("Needs ↓", action: onNeedCare)
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.purple)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.purple.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Test controls"))
    }
}

/// A heart / food emoji that floats up from the baby and fades.
private struct FloatingEmoji: View {
    let emoji: String
    let x: CGFloat
    let reduceMotion: Bool
    @State private var flown = false

    var body: some View {
        Text(emoji)
            .font(.system(size: 30))
            .offset(x: x, y: flown ? -120 : -10)
            .scaleEffect(flown ? 1.15 : 0.6)
            .opacity(flown ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.6 : 1.3)) { flown = true }
            }
    }
}

/// First-visit (and rename) sheet. Suggestions are one tap, so kids who can't type yet can still name the baby.
private struct BabyNamingSheet: View {
    let initialName: String
    let onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private let suggestions = ["Bean", "Mochi", "Pip", "Luna", "Milo", "Coco"]

    var body: some View {
        VStack(spacing: 18) {
            Text("👶").font(.system(size: 54))
            Text("Name your baby").font(.title2.bold())
            TextField("Baby", text: $name)
                .font(.title3)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.background))
                .onChange(of: name) { _, value in
                    if value.count > 16 { name = String(value.prefix(16)) }
                }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { name = suggestion }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                }
            }
            Button {
                onDone(name.trimmingCharacters(in: .whitespacesAndNewlines))
                dismiss()
            } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.accent)
        }
        .padding(24)
        .onAppear { name = initialName }
    }
}

/// Celebration card: a new stage and/or new Baby Book pages. At the "First Word" milestone the player picks
/// what the baby says (one tap).
private struct CelebrationCard: View {
    let celebration: BabyNurseryView.Celebration
    let state: BabyState
    let name: String
    let onPickWord: (String) -> Void
    let onOpenBook: () -> Void
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var milestones: [BabyMilestone] { celebration.milestones }
    private var asksForWord: Bool {
        milestones.contains { $0.id == BabyMilestones.firstWordId } && state.firstWord.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { if !asksForWord { onClose() } }
            if !reduceMotion { ConfettiView().ignoresSafeArea() }
            VStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    BabyAvatarView(stage: celebration.stage ?? state.stage, outfit: state.equippedOutfit,
                                   mood: .delighted, size: 130)
                    if let single = milestones.count == 1 ? milestones.first : nil {
                        Text(single.emoji)
                            .font(.system(size: 40))
                            .padding(6)
                            .background(Circle().fill(Theme.card).shadow(color: .black.opacity(0.12), radius: 4, y: 2))
                    }
                }

                if let stage = celebration.stage {
                    Text("\(name) grew up!").font(.title2.bold())
                    Text("Now a \(stage.title) 🎉")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }

                if milestones.count == 1, let milestone = milestones.first {
                    VStack(spacing: 4) {
                        Text(milestone.title).font(celebration.stage == nil ? .title2.bold() : .headline)
                        Text(milestone.caption(name: name, firstWord: state.firstWord))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if milestones.count > 1 {
                    VStack(spacing: 6) {
                        Text("New Baby Book pages!").font(.headline)
                        ForEach(milestones.prefix(4)) { milestone in
                            Label {
                                Text(milestone.title)
                            } icon: {
                                Text(milestone.emoji)
                            }
                            .font(.subheadline)
                        }
                        if milestones.count > 4 {
                            Text("+\(milestones.count - 4) more").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                if asksForWord {
                    VStack(spacing: 8) {
                        Text("What did \(name) say?").font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                            ForEach(BabyMilestones.firstWordChoices, id: \.self) { word in
                                Button(word) { onPickWord(word) }
                                    .buttonStyle(.bordered)
                                    .tint(Theme.accent)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        if !milestones.isEmpty {
                            Button(action: onOpenBook) {
                                Text("📖 Book").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .tint(Theme.accent)
                        }
                        Button(action: onClose) {
                            Text("Yay!").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Theme.accent)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.card))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 12)
            .padding(20)
        }
    }
}

#Preview {
    NavigationStack {
        BabyNurseryView(feedback: SilentFeedback())
    }
    .modelContainer(for: [LevelProgress.self, BabyProfile.self], inMemory: true)
}
