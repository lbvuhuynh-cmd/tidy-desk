import SwiftUI

/// "Setup Complete!" summary: gentle LED-colour confetti, staggered stars, time / moves / score
/// (score counts up), a "New best!" badge, and next / replay buttons.
struct SetupCompleteView: View {
    let title: String
    let seconds: TimeInterval
    let moves: Int
    let score: Int
    let stars: Int
    let isNewBest: Bool
    /// Baby Corner payout (coins + growth), shown as a row under the stats.
    var babyReward: BabyReward? = nil
    let hasNextLevel: Bool
    let onNext: () -> Void
    let onReplay: () -> Void
    let onLevels: () -> Void

    @State private var appeared = false
    @State private var shownScore = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.3 : 0).ignoresSafeArea()

            if !reduceMotion { ConfettiView().ignoresSafeArea() }

            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(LinearGradient(colors: Array(Theme.led.prefix(3)),
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.bounce, value: appeared)

                VStack(spacing: 4) {
                    Text("Setup Complete!")
                        .font(.title.bold())
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundStyle(index < stars ? Theme.star : Color.secondary.opacity(0.4))
                            .scaleEffect(appeared ? 1 : 0.2)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2 + Double(index) * 0.14),
                                       value: appeared)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(stars) of 3 stars"))

                HStack(spacing: 0) {
                    StatCell(title: "Time", value: ScoreCalculator.formatTime(seconds), systemImage: "timer")
                    Divider().frame(height: 36)
                    StatCell(title: "Moves", value: "\(moves)", systemImage: "hand.draw.fill")
                    Divider().frame(height: 36)
                    StatCell(title: "Score", value: "\(shownScore)", systemImage: "trophy.fill")
                        .contentTransition(.numericText(value: Double(shownScore)))
                }
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.background))
                .accessibilityElement(children: .combine)

                if let babyReward {
                    BabyRewardRow(reward: babyReward)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.55).delay(1.05), value: appeared)
                }

                if isNewBest {
                    Label("New best!", systemImage: "rosette")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accent.opacity(0.15)))
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.9), value: appeared)
                }

                VStack(spacing: 10) {
                    if hasNextLevel {
                        Button(action: onNext) {
                            Label("Next desk", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    HStack(spacing: 10) {
                        Button(action: onReplay) {
                            Label("Replay", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                        }
                        Button(action: onLevels) {
                            Label("All desks", systemImage: "square.grid.2x2").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .tint(Theme.accent)
            }
            .padding(26)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.card))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 12)
            .padding(24)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { appeared = true }
        }
        .task { await countUpScore() }
    }

    /// Rolls the score from 0 to its value in ~0.8 s after the stars land.
    private func countUpScore() async {
        guard !reduceMotion else {
            shownScore = score
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(550))
            let steps = 20
            for step in 1...steps {
                withAnimation(.snappy(duration: 0.08)) { shownScore = score * step / steps }
                try await Task.sleep(for: .milliseconds(40))
            }
        } catch {
            shownScore = score
        }
    }
}

/// "For your baby: 🪙 +25  🌱 +30" (+ "Baby grew!" when a new stage was reached).
private struct BabyRewardRow: View {
    let reward: BabyReward

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Text("👶").font(.title3)
                Text("🪙 +\(reward.coins)").font(.headline.monospacedDigit())
                Text("🌱 +\(reward.growth)").font(.headline.monospacedDigit())
            }
            if let stage = reward.grewTo {
                Text("Your baby grew into a \(stage.title)! 🎉")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            if let first = reward.newMilestones.last {
                // The newest "first" (e.g. "📖 New page: 😊 First Smile"); more than one → "+N".
                Text("📖 New page: \(first.emoji) \(first.title)" + (reward.newMilestones.count > 1 ? " +\(reward.newMilestones.count - 1)" : ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color(red: 1.0, green: 0.9, blue: 0.86).opacity(0.7)))
        .foregroundStyle(Color(red: 0.35, green: 0.25, blue: 0.22))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("For your baby: \(reward.coins) coins and \(reward.growth) growth"))
    }
}

private struct StatCell: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }
}

/// Gentle one-shot confetti burst drawn with Canvas (no assets, cheap).
struct ConfettiView: View {
    private struct Particle {
        let vx: CGFloat, vy: CGFloat, spin: Double, size: CGSize, color: Color, delay: Double
    }

    @State private var start = Date()
    @State private var particles: [Particle] = (0..<60).map { _ in
        Particle(vx: .random(in: -240...240),
                 vy: .random(in: -620 ... -280),
                 spin: .random(in: -8...8),
                 size: CGSize(width: .random(in: 5...9), height: .random(in: 3...5)),
                 color: Theme.led.randomElement() ?? .white,
                 delay: .random(in: 0...0.2))
    }

    private let gravity: CGFloat = 1_000
    private let lifetime: Double = 2.4

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.42)
                for p in particles {
                    let t = elapsed - p.delay
                    guard t > 0, t < lifetime else { continue }
                    let ct = CGFloat(t)
                    var ctx = context
                    ctx.opacity = max(0, 1 - t / lifetime)
                    ctx.translateBy(x: origin.x + p.vx * ct, y: origin.y + p.vy * ct + 0.5 * gravity * ct * ct)
                    ctx.rotate(by: .radians(p.spin * t))
                    ctx.fill(Path(roundedRect: CGRect(x: -p.size.width / 2, y: -p.size.height / 2,
                                                      width: p.size.width, height: p.size.height),
                                  cornerRadius: 1.5),
                             with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
