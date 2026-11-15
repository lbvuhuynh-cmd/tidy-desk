import SwiftUI

/// A multiplication a grown-up answers easily but a young child usually can't (two-digit answer, typed).
struct ParentGateQuestion: Equatable {
    let a: Int
    let b: Int
    var answer: Int { a * b }

    static func random() -> ParentGateQuestion {
        ParentGateQuestion(a: .random(in: 3...9), b: .random(in: 6...9))
    }

    func isAnswered(by text: String) -> Bool {
        Int(text.trimmingCharacters(in: .whitespaces)) == answer
    }
}

/// "Ask a grown-up" before a good deed pays out: answer a multiplication, then hold the button for 2 seconds.
/// Two steps so a child can't tick deeds off alone by tapping, and the grown-up has a moment to say yes.
struct ParentGateView: View {
    let deed: GoodDeed
    let onApprove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var question = ParentGateQuestion.random()
    @State private var answer = ""
    @State private var holdProgress = 0.0
    @FocusState private var answerFocused: Bool

    /// How long the grown-up holds "Approve".
    static let holdDuration = 2.0

    private var isCorrect: Bool { question.isAnswered(by: answer) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    deedSummary
                    VStack(spacing: 10) {
                        Text("For grown-ups")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text("Did your child do this today? Answer to confirm:")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        Text("\(question.a) × \(question.b) = ?")
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .accessibilityLabel(Text("\(question.a) times \(question.b)"))
                        TextField("Answer", text: $answer)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .focused($answerFocused)
                            .frame(width: 140)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.background))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(isCorrect ? Theme.accent : Color.secondary.opacity(0.3), lineWidth: 2)
                            }
                    }
                    holdButton
                    Text(isCorrect ? "Hold for 2 seconds to approve" : "The button wakes up after the right answer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Theme.card.ignoresSafeArea())
            .navigationTitle("Ask a grown-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { answerFocused = true }
            .onChange(of: isCorrect) { _, correct in
                if correct { answerFocused = false }
            }
        }
    }

    private var deedSummary: some View {
        HStack(spacing: 12) {
            Text(deed.emoji)
                .font(.system(size: 34))
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color(hex: deed.category.tint)))
            VStack(alignment: .leading, spacing: 3) {
                Text(deed.title).font(.headline)
                Text("+\(deed.coins) 🪙  ·  +\(deed.growth) 🌱")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.background))
        .accessibilityElement(children: .combine)
    }

    private var holdButton: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.accent.opacity(isCorrect ? 0.25 : 0.1))
            GeometryReader { geo in
                Capsule().fill(Theme.accent)
                    .frame(width: geo.size.width * holdProgress)
            }
            Label("Hold to approve", systemImage: "hand.thumbsup.fill")
                .font(.headline)
                .foregroundStyle(isCorrect ? (holdProgress > 0.5 ? .white : Theme.accent) : .secondary)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 56)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 40) {
            approve()
        } onPressingChanged: { pressing in
            if pressing && isCorrect {
                withAnimation(.linear(duration: Self.holdDuration)) { holdProgress = 1 }
            } else if !pressing {
                withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Approve"))
        .accessibilityHint(Text(isCorrect ? "Approves the good deed" : "Answer the question first"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { approve() }
    }

    private func approve() {
        guard isCorrect else { return }
        onApprove()
        dismiss()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ParentGateView(deed: GoodDeeds.chores) {}
    }
}
