import SwiftUI

/// The Baby Book: one page per milestone, like a photo album. Reached pages show the baby at that age, the
/// milestone and the day it happened; upcoming pages are soft silhouettes with "At 8 months".
/// TestFlight (`BetaConfig.unlockAllBabyContent`): upcoming pages are shown in full with a "Preview" tag.
struct BabyBookView: View {
    let state: BabyState
    let name: String
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(BabyMilestones.all) { milestone in
                            BookPage(milestone: milestone,
                                     date: state.milestoneDates[milestone.id],
                                     isPreview: BetaConfig.unlockAllBabyContent && state.milestoneDates[milestone.id] == nil,
                                     outfit: state.equippedOutfit,
                                     name: name,
                                     firstWord: state.firstWord)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("\(name)'s Baby Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            BabyAvatarView(stage: state.stage, outfit: state.equippedOutfit, mood: .delighted, size: 74)
                .background(Circle().fill(Color(red: 1.0, green: 0.92, blue: 0.88)))
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.title2.bold())
                Text("\(BabyGrowth.ageText(months: state.months)) · \(state.stage.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("📖 \(state.reachedMilestones.count) of \(BabyMilestones.all.count) pages")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
        .accessibilityElement(children: .combine)
    }
}

private struct BookPage: View {
    let milestone: BabyMilestone
    let date: Date?
    let isPreview: Bool
    let outfit: BabyShopItem?
    let name: String
    let firstWord: String

    private var isOpen: Bool { date != nil || isPreview }

    /// Soft pastel "photo" background, a different tint per stage.
    private var tint: Color {
        switch milestone.stage {
        case .newborn: Color(red: 1.0, green: 0.92, blue: 0.88)
        case .infant: Color(red: 1.0, green: 0.95, blue: 0.82)
        case .roller: Color(red: 0.88, green: 0.95, blue: 0.86)
        case .crawler: Color(red: 0.86, green: 0.93, blue: 0.99)
        case .toddler: Color(red: 0.93, green: 0.89, blue: 0.99)
        case .explorer: Color(red: 0.99, green: 0.89, blue: 0.93)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isOpen ? tint : Color.secondary.opacity(0.12))
                BabyAvatarView(stage: milestone.stage, outfit: outfit, mood: isOpen ? .delighted : .sleepy, size: 92)
                    .opacity(isOpen ? 1 : 0.18)
                    .saturation(isOpen ? 1 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(isOpen ? milestone.emoji : "❔")
                    .font(.system(size: 26))
                    .padding(8)
            }
            .frame(height: 118)

            Text(isOpen ? milestone.title : "Coming soon")
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if isOpen {
                Text(milestone.caption(name: name, firstWord: firstWord))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            footer
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(footerTint.opacity(0.14)))
                .foregroundStyle(footerTint)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay {
            if !isOpen {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var footer: some View {
        if let date {
            Text("\(BabyGrowth.ageText(months: milestone.month)) · \(date.formatted(.dateTime.month(.abbreviated).day()))")
        } else if isPreview {
            Text("Preview · \(BabyGrowth.ageText(months: milestone.month))")
        } else {
            Text("At \(BabyGrowth.ageText(months: milestone.month).lowercased())")
        }
    }

    private var footerTint: Color {
        if date != nil { return Theme.accent }
        if isPreview { return .purple }
        return .secondary
    }
}

#Preview {
    BabyBookView(state: {
        var state = BabyState()
        state.setAgeForTesting(months: 8)
        return state
    }(), name: "Bean")
}
