import SwiftUI
import SwiftData

/// Baby Corner: the baby's room. Coins earned by tidying desks buy milk and snacks, toys and outfits.
///
/// Built for young players too: big emoji buttons, short words, nothing ever goes wrong. When the baby is full or
/// coins run short, a friendly note says to tidy a desk; tapping the baby (giggles + hearts) is always free.
/// Rules: `BabyState`. Sounds + haptics: `BabyFeedback` (→ `FeedbackEngine`).
struct BabyNurseryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \BabyProfile.createdAt) private var profiles: [BabyProfile]

    /// `nil` = `FeedbackEngine.shared` (resolved on the main actor; tests and previews pass `SilentFeedback`).
    var feedback: BabyFeedback?

    private var fx: BabyFeedback { feedback ?? FeedbackEngine.shared }

    enum CareTab: CaseIterable {
        case feed, play, dress

        var title: String {
            switch self {
            case .feed: "Feed"
            case .play: "Play"
            case .dress: "Dress"
            }
        }

        var emoji: String {
            switch self {
            case .feed: "🍼"
            case .play: "🧸"
            case .dress: "👕"
            }
        }

        var kind: BabyShopItem.Kind {
            switch self {
            case .feed: .food
            case .play: .toy
            case .dress: .outfit
            }
        }
    }

    private struct FloatingBit: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
    }

    @State private var tab: CareTab = .feed
    @State private var mood: BabyAvatarView.Mood = .content
    @State private var moodTask: Task<Void, Never>?
    @State private var bounce = 0
    @State private var bits: [FloatingBit] = []
    @State private var note: String?
    @State private var noteTask: Task<Void, Never>?
    @State private var grewTo: BabyStage?
    @State private var showNaming = false
    @State private var didAskName = false

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
        .overlay {
            if let grewTo {
                GrowUpCard(stage: grewTo, name: profiles.first?.displayName ?? "Baby") {
                    withAnimation(.easeOut(duration: 0.2)) { self.grewTo = nil }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: Layout

    private func content(_ profile: BabyProfile) -> some View {
        let state = profile.state
        return VStack(spacing: 14) {
            topBar(coins: state.coins)
            nameRow(profile, state: state)
            room(profile, state: state)
            HStack(spacing: 12) {
                NeedMeter(emoji: "🍼", title: "Tummy", value: state.tummy / BabyState.maxNeed,
                          color: Color(red: 0.98, green: 0.72, blue: 0.45))
                NeedMeter(emoji: "💗", title: "Joy", value: state.joy / BabyState.maxNeed,
                          color: Color(red: 0.95, green: 0.55, blue: 0.68))
            }
            tabPicker
            itemShelf(state: state)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .overlay(alignment: .bottom) { noteToast }
    }

    private func topBar(coins: Int) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
            }
            .accessibilityLabel(Text("Back to desks"))
            Text("Baby Corner")
                .font(.title2.bold())
            Spacer()
            CoinPill(coins: coins)
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
                Text(state.stage.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            GrowthBar(progress: state.stageProgress, next: state.stage.next)
        }
    }

    private func room(_ profile: BabyProfile, state: BabyState) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.93, blue: 0.9), Color(red: 0.98, green: 0.95, blue: 0.86)],
                                     startPoint: .top, endPoint: .bottom))
            // Play rug.
            Ellipse()
                .fill(Color(red: 0.8, green: 0.88, blue: 0.95))
                .frame(height: 70)
                .padding(.horizontal, 40)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)

            Button(action: tapBaby) {
                BabyAvatarView(stage: state.stage, outfit: state.equippedOutfit, mood: mood, size: 190)
                    .keyframeAnimator(initialValue: 1.0, trigger: bounce) { view, scale in
                        view.scaleEffect(scale, anchor: .bottom)
                    } keyframes: { _ in
                        SpringKeyframe(reduceMotion ? 1.0 : 1.1, duration: 0.14)
                        SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Tap to cuddle"))

            // What the baby would like (a gentle thought bubble, never crying).
            if state.wantsFood || state.wantsPlay {
                Text(state.wantsFood ? "🍼" : "🧸")
                    .font(.system(size: 26))
                    .padding(10)
                    .background(Circle().fill(.white).shadow(color: .black.opacity(0.1), radius: 4, y: 2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(18)
                    .accessibilityLabel(Text(state.wantsFood ? "Baby would like some milk" : "Baby would like to play"))
            }

            ForEach(bits) { bit in
                FloatingEmoji(emoji: bit.emoji, x: bit.x, reduceMotion: reduceMotion)
            }
        }
        .frame(height: 250)
    }

    private var tabPicker: some View {
        HStack(spacing: 10) {
            ForEach(CareTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.snappy) { tab = item }
                } label: {
                    VStack(spacing: 2) {
                        Text(item.emoji).font(.system(size: 28))
                        Text(item.title).font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(tab == item ? Theme.accent.opacity(0.18) : Theme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(tab == item ? Theme.accent : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
    }

    private func itemShelf(state: BabyState) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(BabyCatalog.items(of: tab.kind)) { item in
                    Button { use(item) } label: {
                        ShopItemCard(item: item, state: state)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .id(tab) // start each tab scrolled to the left
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

    private func use(_ item: BabyShopItem) {
        guard let profile = profiles.first else { return }
        let name = profile.displayName
        let result: CareResult
        switch item.kind {
        case .food:
            result = profile.update { $0.feed(item) }
            if case .done = result { fx.babyFed() }
        case .toy:
            result = profile.update { (state: inout BabyState) -> CareResult in
                if !state.owns(item) {
                    let bought = state.buy(item)
                    guard bought.isDone else { return bought }
                }
                return state.play(with: item)
            }
            if case .done = result { fx.babyPlayed() }
        case .outfit:
            let wasOwned = profile.state.owns(item)
            result = profile.update { (state: inout BabyState) -> CareResult in
                if !state.owns(item) {
                    let bought = state.buy(item)
                    guard bought.isDone else { return bought }
                }
                return state.wear(item)
            }
            if case .done = result {
                if wasOwned { fx.outfitChanged() } else { fx.itemBought() }
            }
        }
        try? modelContext.save()

        switch result {
        case .done(let grew):
            react(with: item.kind == .outfit ? "✨" : item.emoji, count: 1)
            if item.kind != .outfit { react(with: "💗", count: 1) }
            if let grew { celebrate(grew) }
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

    private func celebrate(_ stage: BabyStage) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            fx.babyGrew()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { grewTo = stage }
        }
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
    let next: BabyStage?

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
            Text(next.map { "🌱 Growing into a \($0.title)" } ?? "🌟 All grown up (for now)!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(next.map { "Growing into a \($0.title), \(Int(progress * 100)) percent" } ?? "All grown up"))
    }
}

private struct NeedMeter: View {
    let emoji: String
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.2))
                        Capsule().fill(color)
                            .frame(width: max(6, geo.size.width * min(1, max(0, value))))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title) \(Int(value * 100)) percent"))
    }
}

private struct ShopItemCard: View {
    let item: BabyShopItem
    let state: BabyState

    private var tooYoung: Bool { state.stage < item.minStage }
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

/// "Look who's growing up!" card when the baby reaches a new stage.
private struct GrowUpCard: View {
    let stage: BabyStage
    let name: String
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture(perform: onClose)
            if !reduceMotion { ConfettiView().ignoresSafeArea() }
            VStack(spacing: 14) {
                BabyAvatarView(stage: stage, mood: .delighted, size: 150)
                Text("\(name) grew up!").font(.title2.bold())
                Text("Now a \(stage.title) 🎉")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Button(action: onClose) {
                    Text("Yay!").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.accent)
            }
            .padding(26)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.card))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 12)
        }
    }
}

#Preview {
    NavigationStack {
        BabyNurseryView(feedback: SilentFeedback())
    }
    .modelContainer(for: [LevelProgress.self, BabyProfile.self], inMemory: true)
}
