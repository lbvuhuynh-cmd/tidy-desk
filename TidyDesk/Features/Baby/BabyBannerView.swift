import SwiftUI

/// Baby Corner shortcut on the level menu: the baby, its growth, coins, and what it would like right now.
/// `profile == nil` (never visited) shows a "Meet your baby" invitation.
struct BabyBannerView: View {
    let profile: BabyProfile?

    var body: some View {
        let state = profile?.state ?? BabyState()
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.92, blue: 0.88), Color(red: 0.98, green: 0.95, blue: 0.86)],
                                         startPoint: .top, endPoint: .bottom))
                BabyAvatarView(stage: state.stage, outfit: state.equippedOutfit,
                               mood: profile == nil ? .sleepy : .content, size: 60)
                if profile != nil, let wish = state.wish {
                    Text(wish.emoji)
                        .font(.system(size: 14))
                        .padding(4)
                        .background(Circle().fill(.white).shadow(color: .black.opacity(0.12), radius: 2, y: 1))
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("Baby Corner")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let profile {
                    Text("\(profile.displayName) · \(BabyGrowth.ageText(months: state.months))")
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(state.stage.title) · 📖 \(state.reachedMilestones.count)/\(BabyMilestones.all.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressView(value: state.monthProgress)
                        .tint(Theme.accent)
                } else {
                    Text("Meet your baby!")
                        .font(.headline)
                    Text("Tidy desks to earn 🪙, watch your baby grow month by month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                if profile != nil {
                    Text("🪙 \(state.coins)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens Baby Corner"))
    }
}
