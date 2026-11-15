import SwiftUI
import SwiftData

/// Good Deeds: a sticker chart for real-world habits (exercise, helping at home, school, kindness).
/// The child taps a deed, a grown-up confirms it (`ParentGateView`), and it pays coins + a little growth into
/// Baby Corner while the baby claps and hearts fly. Each deed has a daily limit (`GoodDeed.dailyLimit`);
/// TestFlight (`BetaConfig.unlockAllBabyContent`) lifts it for testing.
/// Rules: `BabyState.logGoodDeed`. Sounds + haptics: `BabyFeedback.goodDeedLogged`.
struct GoodDeedsView: View {
    /// `nil` = `FeedbackEngine.shared` (previews and tests pass `SilentFeedback`).
    var feedback: BabyFeedback?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \BabyProfile.createdAt) private var profiles: [BabyProfile]

    @State private var gateDeed: GoodDeed?
    @State private var cheer = 0
    @State private var bits: [Bit] = []
    @State private var note: String?
    @State private var noteTask: Task<Void, Never>?

    private struct Bit: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
    }

    private var fx: BabyFeedback { feedback ?? FeedbackEngine.shared }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let state = profiles.first?.state ?? BabyState()
        let name = profiles.first?.displayName ?? "Baby"
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header(state: state, name: name)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(GoodDeeds.all) { deed in
                            Button { tap(deed, state: state) } label: {
                                DeedCard(deed: deed,
                                         timesToday: state.timesDone(deed),
                                         canDo: state.canDo(deed))
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                    WeekStickers(entries: state.goodDeedsThisWeek())
                    if BetaConfig.unlockAllBabyContent {
                        Text("Test build · no daily limit")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.purple)
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Good Deeds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) { noteToast }
        }
        .sheet(item: $gateDeed) { deed in
            ParentGateView(deed: deed) { approve(deed, name: name) }
        }
        .onAppear { _ = BabyStore.profile(in: modelContext) }
    }

    private func header(state: BabyState, name: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(red: 1.0, green: 0.92, blue: 0.88))
                LivelyBabyView(stage: state.stage, outfit: state.equippedOutfit, size: 84, cheer: cheer)
                ForEach(bits) { bit in
                    FloatingEmoji(emoji: bit.emoji, x: bit.x, reduceMotion: reduceMotion)
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(name) loves good deeds!")
                    .font(.headline)
                Text("Did something good today? Ask a grown-up to tick it off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                CoinPill(coins: state.coins)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
    }

    @ViewBuilder
    private var noteToast: some View {
        if let note {
            Text(note)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.card).shadow(color: .black.opacity(0.12), radius: 8, y: 3))
                .padding(.bottom, 20)
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func tap(_ deed: GoodDeed, state: BabyState) {
        guard state.canDo(deed) else {
            fx.careDeclined()
            show("Already ticked off today. See you tomorrow! 🌙")
            return
        }
        gateDeed = deed
    }

    private func approve(_ deed: GoodDeed, name: String) {
        guard case .done(let reward) = BabyStore.logGoodDeed(deed, in: modelContext) else {
            fx.careDeclined()
            show("Already ticked off today. See you tomorrow! 🌙")
            return
        }
        Task { @MainActor in
            // Let the grown-up sheet slide away first, so the cheer is seen.
            try? await Task.sleep(for: .milliseconds(350))
            fx.goodDeedLogged()
            cheer += 1
            burst(["💗", "🪙", deed.emoji, "💗", "⭐️"])
            var text = "+\(reward.coins) 🪙 · \(name) is so proud of you!"
            if let page = reward.newMilestones.last {
                text += "\n📖 New page: \(page.emoji) \(page.title)"
            } else if let stage = reward.grewTo {
                text += "\n🎉 \(name) is now a \(stage.title)!"
            }
            show(text)
        }
    }

    private func burst(_ emojis: [String]) {
        let new = emojis.enumerated().map { index, emoji in
            Bit(emoji: emoji, x: CGFloat(index - emojis.count / 2) * 16 + .random(in: -6...6))
        }
        bits.append(contentsOf: new)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            let ids = Set(new.map(\.id))
            bits.removeAll { ids.contains($0.id) }
        }
    }

    private func show(_ text: String) {
        noteTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { note = text }
        noteTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { note = nil }
        }
    }
}

/// One deed: big emoji on a pastel circle, title, example, reward, and today's status.
private struct DeedCard: View {
    let deed: GoodDeed
    let timesToday: Int
    let canDo: Bool

    private var doneForToday: Bool { !canDo }

    var body: some View {
        VStack(spacing: 8) {
            Text(deed.emoji)
                .font(.system(size: 38))
                .frame(width: 70, height: 70)
                .background(Circle().fill(Color(hex: deed.category.tint)))
                .overlay(alignment: .bottomTrailing) {
                    if doneForToday {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, Theme.accent)
                            .offset(x: 4, y: 4)
                    }
                }
            Text(deed.title)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(deed.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(status)
                .font(.caption.weight(.bold).monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill((doneForToday ? Color.secondary : Theme.accent).opacity(0.14)))
                .foregroundStyle(doneForToday ? Color.secondary : Theme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .opacity(doneForToday ? 0.75 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(doneForToday ? "Done for today" : "Ask a grown-up to confirm"))
    }

    private var status: String {
        if doneForToday { return "✓ Done today" }
        if deed.dailyLimit > 1 { return "+\(deed.coins) 🪙 · \(timesToday)/\(deed.dailyLimit) today" }
        return "+\(deed.coins) 🪙"
    }
}

/// "This week": one sticker per deed from the last 7 days.
private struct WeekStickers: View {
    let entries: [GoodDeedEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This week").font(.headline)
                Spacer()
                Text("\(entries.count) ⭐️").font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            if entries.isEmpty {
                Text("No stickers yet. Every good deed adds one here!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 6)], spacing: 6) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        Text(GoodDeeds.deed(id: entry.deedId)?.emoji ?? "⭐️")
                            .font(.system(size: 22))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(hex: GoodDeeds.deed(id: entry.deedId)?.category.tint ?? 0xF6E7D4)))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("This week: \(entries.count) good deeds"))
    }
}

#Preview {
    GoodDeedsView(feedback: SilentFeedback())
        .modelContainer(for: [LevelProgress.self, BabyProfile.self], inMemory: true)
}
