import SwiftUI

/// `BabyAvatarView` with a little life in it, for places where the baby just "hangs out" (nursery, menu banner,
/// level-complete card):
///
/// * **Idle** (only while `mood == .content`): breathes softly, blinks every few seconds (sometimes twice),
///   now and then wiggles, and yawns: rarely, or often when `drowsy` (low on sleep).
/// * **Cheer**: change `cheer` (or set `cheerOnAppear`) and the baby claps 👏 and hops with a big smile, e.g. when
///   the player has just tidied a desk.
///
/// Real artwork can't blink or open its mouth, so with art the baby wiggles instead of blinking and a 🥱 badge
/// shows the yawn. Reduce Motion: no breathing, wiggles or hops (blinks, yawns and claps stay; they don't move).
struct LivelyBabyView: View {
    let stage: BabyStage
    var outfit: BabyShopItem? = BabyCatalog.item(id: BabyCatalog.defaultOutfitId)
    var mood: BabyAvatarView.Mood = .content
    var size: CGFloat = 160
    /// Low on sleep: yawns come much more often.
    var drowsy = false
    /// Change this value to make the baby cheer.
    var cheer = 0
    /// Cheer once when the view appears, after `cheerDelay` seconds.
    var cheerOnAppear = false
    var cheerDelay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blinking = false
    @State private var yawning = false
    @State private var cheering = false
    @State private var wiggle = 0
    @State private var hop = 0
    @State private var cheerTask: Task<Void, Never>?

    private struct Motion {
        var y: CGFloat = 0
        var angle: Double = 0
    }

    private var hasArt: Bool { BabyAvatarView.hasArt(for: stage) }

    var body: some View {
        BabyAvatarView(stage: stage, outfit: outfit, mood: cheering ? .delighted : mood, size: size,
                       eyesClosed: blinking, yawning: yawning)
            // Breathing: a slow, tiny rise and fall.
            .phaseAnimator(reduceMotion ? [false] : [false, true]) { view, inhale in
                view.scaleEffect(x: 1, y: inhale ? 1.02 : 1, anchor: .bottom)
            } animation: { _ in
                .easeInOut(duration: 1.8)
            }
            // Idle wiggle.
            .keyframeAnimator(initialValue: Motion(), trigger: wiggle) { view, motion in
                view.rotationEffect(.degrees(motion.angle), anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.angle) {
                    CubicKeyframe(-4, duration: 0.18)
                    CubicKeyframe(4, duration: 0.3)
                    CubicKeyframe(0, duration: 0.22)
                }
            }
            // Cheer: three happy hops.
            .keyframeAnimator(initialValue: Motion(), trigger: hop) { view, motion in
                view.offset(y: motion.y)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    SpringKeyframe(-size * 0.08, duration: 0.16)
                    SpringKeyframe(0, duration: 0.2)
                    SpringKeyframe(-size * 0.08, duration: 0.16)
                    SpringKeyframe(0, duration: 0.2)
                    SpringKeyframe(-size * 0.06, duration: 0.16)
                    SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                }
            }
            .overlay {
                if cheering {
                    HStack {
                        clap
                        Spacer(minLength: 0)
                        clap.scaleEffect(x: -1, y: 1)
                    }
                    .offset(y: -size * 0.12)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topLeading) {
                if yawning && hasArt {
                    Text("🥱")
                        .font(.system(size: max(12, size * 0.16)))
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .task(id: mood == .content) {
                guard mood == .content else { return }
                await idleLoop()
            }
            .onChange(of: cheer) { startCheer(after: 0) }
            .onAppear { if cheerOnAppear { startCheer(after: cheerDelay) } }
            .onDisappear { cheerTask?.cancel() }
    }

    private var clap: some View {
        Text("👏")
            .font(.system(size: max(12, size * 0.2)))
            .phaseAnimator([1.0, 1.25]) { view, scale in
                view.scaleEffect(scale)
            } animation: { _ in
                .easeInOut(duration: 0.16)
            }
    }

    // MARK: Behaviour

    /// Random little things every 2.5–5 s until the view goes away or the mood changes.
    private func idleLoop() async {
        while !Task.isCancelled {
            guard await pause(.random(in: 2.5...5.0)) else { return }
            if cheering { continue }
            let roll = Double.random(in: 0..<1)
            if roll < (drowsy ? 0.35 : 0.07) {
                await yawn()
            } else if roll < 0.82 && !hasArt {
                await blink()
                if Bool.random() {
                    guard await pause(0.18) else { return }
                    await blink()
                }
            } else if !reduceMotion {
                wiggle += 1
            }
        }
    }

    private func blink() async {
        blinking = true
        _ = await pause(0.13)
        blinking = false
    }

    private func yawn() async {
        withAnimation(.easeInOut(duration: 0.25)) { yawning = true }
        _ = await pause(1.2)
        withAnimation(.easeInOut(duration: 0.3)) { yawning = false }
    }

    private func startCheer(after delay: Double) {
        cheerTask?.cancel()
        cheerTask = Task { @MainActor in
            if delay > 0 { guard await pause(delay) else { return } }
            blinking = false
            yawning = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { cheering = true }
            if !reduceMotion { hop += 1 }
            guard await pause(1.8) else { return }
            withAnimation(.easeOut(duration: 0.3)) { cheering = false }
        }
    }

    /// Sleeps; false when the task was cancelled (view gone).
    private func pause(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }
}

#Preview("Idle + cheer") {
    struct Demo: View {
        @State private var cheer = 0
        var body: some View {
            VStack(spacing: 24) {
                HStack {
                    ForEach([BabyStage.infant, .crawler, .toddler], id: \.self) { stage in
                        LivelyBabyView(stage: stage, size: 100, drowsy: true, cheer: cheer)
                    }
                }
                Button("Cheer") { cheer += 1 }
            }
            .padding()
        }
    }
    return Demo()
}
