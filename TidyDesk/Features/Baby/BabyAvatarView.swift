import SwiftUI
import UIKit

/// The baby, drawn in code until real artwork exists.
///
/// * Real art: when `Assets.xcassets` has `baby_newborn` / `baby_infant` / `baby_roller` / `baby_crawler` /
///   `baby_toddler` / `baby_explorer`
///   (see `BabyStage.assetName`), that picture is shown instead and the outfit appears as a small badge.
/// * Drawn placeholder: round head, rosy cheeks, outfit-coloured body that changes shape with the stage
///   (swaddled newborn → sitting infant → tummy-time roller → crawler → standing toddler → taller explorer),
///   plus the outfit's emoji
///   as a little hat. `mood` changes the face.
struct BabyAvatarView: View {
    enum Mood: Equatable {
        /// Calm, eyes open.
        case content
        /// Squinty happy eyes, big smile (just tapped, fed or played with).
        case delighted
        /// Sleepy closed eyes (newborn resting).
        case sleepy
        /// Fast asleep (after a lullaby): closed eyes, small "z" bubbles.
        case asleep
    }

    let stage: BabyStage
    var outfit: BabyShopItem? = BabyCatalog.item(id: BabyCatalog.defaultOutfitId)
    var mood: Mood = .content
    var size: CGFloat = 160
    /// Momentary closed eyes (a blink, see `LivelyBabyView`). Drawn baby only.
    var eyesClosed = false
    /// Mid-yawn: closed eyes and a round open mouth. Drawn baby only (real art gets a 🥱 badge from `LivelyBabyView`).
    var yawning = false

    /// True when real artwork exists for this stage (then the face can't blink or yawn).
    static func hasArt(for stage: BabyStage) -> Bool { UIImage(named: stage.assetName) != nil }

    private static let skin = Color(red: 1.0, green: 0.86, blue: 0.74)
    private static let skinShade = Color(red: 0.95, green: 0.74, blue: 0.62)
    private static let hair = Color(red: 0.45, green: 0.32, blue: 0.24)
    private static let cheek = Color(red: 1.0, green: 0.6, blue: 0.62)
    private static let ink = Color(red: 0.3, green: 0.22, blue: 0.2)

    var body: some View {
        Group {
            if Self.hasArt(for: stage) {
                Image(stage.assetName)
                    .resizable()
                    .scaledToFit()
                    .overlay(alignment: .topTrailing) {
                        if let outfit, outfit.id != BabyCatalog.defaultOutfitId {
                            Text(outfit.emoji).font(.system(size: size * 0.18))
                        }
                    }
            } else {
                drawn
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text("Baby, \(stage.title)"))
    }

    // MARK: Drawn placeholder

    private var outfitColor: Color { Color(hex: outfit?.color ?? 0xF6E7D4) }
    private var scale: CGFloat {
        switch stage {
        case .newborn: 0.82
        case .infant: 0.88
        case .roller: 0.92
        case .crawler: 0.96
        case .toddler: 1.0
        case .explorer: 1.0
        }
    }

    private var drawn: some View {
        let s = size * scale
        let head = s * 0.5
        return ZStack {
            // Soft floor shadow.
            Ellipse()
                .fill(.black.opacity(0.08))
                .frame(width: s * 0.7, height: s * 0.1)
                .offset(y: s * 0.46)

            bodyShape(s: s)

            // Head.
            ZStack {
                Circle().fill(Self.skin)
                Circle().strokeBorder(Self.skinShade, lineWidth: max(1, s * 0.012))
                ears(head: head)
                hairTufts(head: head)
                face(head: head)
            }
            .frame(width: head, height: head)
            .offset(y: headOffset(s: s))

            if mood == .asleep {
                Text("z z")
                    .font(.system(size: head * 0.22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.6, blue: 0.85))
                    .offset(x: head * 0.55, y: headOffset(s: s) - head * 0.5)
            }

            // Outfit "hat" (emoji) for anything but the plain onesie.
            if let outfit, outfit.id != BabyCatalog.defaultOutfitId {
                Text(outfit.emoji)
                    .font(.system(size: head * 0.36))
                    .rotationEffect(.degrees(-12))
                    .offset(x: head * 0.3, y: headOffset(s: s) - head * 0.46)
            }
        }
        .frame(width: size, height: size)
    }

    private func headOffset(s: CGFloat) -> CGFloat {
        switch stage {
        case .newborn: -s * 0.1
        case .infant: -s * 0.14
        case .roller: -s * 0.02
        case .crawler: -s * 0.1
        case .toddler: -s * 0.2
        case .explorer: -s * 0.24
        }
    }

    @ViewBuilder
    private func bodyShape(s: CGFloat) -> some View {
        let fill = outfitColor
        let edge = fill.opacity(0.6)
        switch stage {
        case .newborn:
            // Swaddle: a soft bean wrapped around the body.
            Capsule()
                .fill(fill)
                .overlay(Capsule().strokeBorder(edge, lineWidth: s * 0.015))
                .overlay(
                    // Wrap fold.
                    Capsule().fill(.white.opacity(0.35)).frame(width: s * 0.5, height: s * 0.06).rotationEffect(.degrees(-18))
                )
                .frame(width: s * 0.62, height: s * 0.5)
                .offset(y: s * 0.2)
        case .infant:
            // Sitting: round body, little arms.
            ZStack {
                limb(w: s * 0.13, h: s * 0.24).rotationEffect(.degrees(30)).offset(x: -s * 0.27, y: s * 0.12)
                limb(w: s * 0.13, h: s * 0.24).rotationEffect(.degrees(-30)).offset(x: s * 0.27, y: s * 0.12)
                Ellipse().fill(fill).overlay(Ellipse().strokeBorder(edge, lineWidth: s * 0.015))
                    .frame(width: s * 0.52, height: s * 0.48).offset(y: s * 0.18)
                foot(s: s).offset(x: -s * 0.14, y: s * 0.4)
                foot(s: s).offset(x: s * 0.14, y: s * 0.4)
            }
        case .roller:
            // Tummy time: lying flat, head lifted, hands on the rug, feet kicking behind.
            ZStack {
                foot(s: s).offset(x: -s * 0.36, y: s * 0.26)
                foot(s: s).offset(x: s * 0.36, y: s * 0.26)
                Capsule().fill(fill).overlay(Capsule().strokeBorder(edge, lineWidth: s * 0.015))
                    .frame(width: s * 0.78, height: s * 0.3).offset(y: s * 0.3)
                hand(s: s).offset(x: -s * 0.22, y: s * 0.4)
                hand(s: s).offset(x: s * 0.22, y: s * 0.4)
            }
        case .crawler:
            // On hands and knees: wide body, hands in front.
            ZStack {
                Ellipse().fill(fill).overlay(Ellipse().strokeBorder(edge, lineWidth: s * 0.015))
                    .frame(width: s * 0.74, height: s * 0.42).offset(y: s * 0.2)
                hand(s: s).offset(x: -s * 0.2, y: s * 0.4)
                hand(s: s).offset(x: s * 0.2, y: s * 0.4)
            }
        case .toddler, .explorer:
            // Standing: body, arms out a bit, two legs (the explorer is a little taller).
            ZStack {
                limb(w: s * 0.13, h: s * 0.26).rotationEffect(.degrees(25)).offset(x: -s * 0.25, y: s * 0.06)
                limb(w: s * 0.13, h: s * 0.26).rotationEffect(.degrees(-25)).offset(x: s * 0.25, y: s * 0.06)
                Capsule().fill(fill).frame(width: s * 0.15, height: s * 0.26).offset(x: -s * 0.1, y: s * 0.34)
                Capsule().fill(fill).frame(width: s * 0.15, height: s * 0.26).offset(x: s * 0.1, y: s * 0.34)
                RoundedRectangle(cornerRadius: s * 0.16, style: .continuous).fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: s * 0.16, style: .continuous).strokeBorder(edge, lineWidth: s * 0.015))
                    .frame(width: s * 0.44, height: s * 0.4).offset(y: s * 0.12)
                foot(s: s).offset(x: -s * 0.11, y: s * 0.47)
                foot(s: s).offset(x: s * 0.11, y: s * 0.47)
            }
            .scaleEffect(x: 1, y: stage == .explorer ? 1.1 : 1, anchor: .top)
        }
    }

    private func limb(w: CGFloat, h: CGFloat) -> some View {
        Capsule().fill(outfitColor).frame(width: w, height: h)
            .overlay(alignment: .bottom) { Circle().fill(Self.skin).frame(width: w * 0.9, height: w * 0.9).offset(y: w * 0.2) }
    }

    private func foot(s: CGFloat) -> some View {
        Ellipse().fill(Self.skin).overlay(Ellipse().strokeBorder(Self.skinShade, lineWidth: 1))
            .frame(width: s * 0.13, height: s * 0.09)
    }

    private func hand(s: CGFloat) -> some View {
        Circle().fill(Self.skin).overlay(Circle().strokeBorder(Self.skinShade, lineWidth: 1))
            .frame(width: s * 0.12, height: s * 0.12)
    }

    private func ears(head: CGFloat) -> some View {
        HStack(spacing: head * 0.82) {
            Circle().fill(Self.skin).frame(width: head * 0.18)
            Circle().fill(Self.skin).frame(width: head * 0.18)
        }
        .zIndex(-1)
    }

    /// More hair as the baby grows: one curl → two → a little fringe.
    private func hairTufts(head: CGFloat) -> some View {
        let count = min(stage.rawValue + 1, 5)
        return HStack(spacing: -head * 0.04) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .trim(from: 0.05, to: 0.55)
                    .stroke(Self.hair, style: StrokeStyle(lineWidth: head * 0.05, lineCap: .round))
                    .frame(width: head * 0.16, height: head * 0.16)
                    .rotationEffect(.degrees(Double(i - count / 2) * 18 + 180))
            }
        }
        .offset(y: -head * 0.45)
    }

    private func face(head: CGFloat) -> some View {
        let eyeGap = head * 0.32
        return ZStack {
            // Cheeks.
            HStack(spacing: head * 0.46) {
                Circle().fill(Self.cheek.opacity(0.55)).frame(width: head * 0.16)
                Circle().fill(Self.cheek.opacity(0.55)).frame(width: head * 0.16)
            }
            .offset(y: head * 0.12)

            // Eyes.
            HStack(spacing: eyeGap) {
                eye(head: head)
                eye(head: head)
            }
            .offset(y: -head * 0.02)

            mouth(head: head)
                .offset(y: head * 0.2)
        }
    }

    @ViewBuilder
    private func eye(head: CGFloat) -> some View {
        let base: Mood = (stage == .newborn && mood == .content) ? .sleepy : mood
        let effective: Mood = (eyesClosed || yawning) && base != .delighted ? .sleepy : base
        switch effective {
        case .asleep:
            HappyEye().stroke(Self.ink, style: StrokeStyle(lineWidth: head * 0.03, lineCap: .round))
                .frame(width: head * 0.12, height: head * 0.05)
                .rotationEffect(.degrees(180))
        case .content:
            Circle().fill(Self.ink).frame(width: head * 0.1, height: head * 0.11)
                .overlay(alignment: .topLeading) { Circle().fill(.white).frame(width: head * 0.035).offset(x: head * 0.015, y: head * 0.015) }
        case .delighted:
            // ^ ^
            HappyEye().stroke(Self.ink, style: StrokeStyle(lineWidth: head * 0.035, lineCap: .round))
                .frame(width: head * 0.13, height: head * 0.07)
        case .sleepy:
            // ‿ ‿
            HappyEye().stroke(Self.ink, style: StrokeStyle(lineWidth: head * 0.03, lineCap: .round))
                .frame(width: head * 0.12, height: head * 0.05)
                .rotationEffect(.degrees(180))
        }
    }

    @ViewBuilder
    private func mouth(head: CGFloat) -> some View {
        if yawning && mood != .delighted {
            // Big round "O".
            Ellipse().fill(Color(red: 0.7, green: 0.3, blue: 0.34))
                .frame(width: head * 0.12, height: head * 0.15)
                .offset(y: head * 0.02)
        } else {
            mouthShape(head: head)
        }
    }

    @ViewBuilder
    private func mouthShape(head: CGFloat) -> some View {
        switch mood {
        case .delighted:
            Smile().fill(Color(red: 0.85, green: 0.38, blue: 0.42))
                .frame(width: head * 0.2, height: head * 0.11)
        case .content, .sleepy, .asleep:
            Smile().stroke(Self.ink, style: StrokeStyle(lineWidth: head * 0.028, lineCap: .round))
                .frame(width: head * 0.13, height: head * 0.05)
        }
    }
}

/// An upward arc "^" (rotate 180° for a closed sleepy eye).
private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        return p
    }
}

/// A "D"-shaped smile: flat top, round bottom.
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY))
        return p
    }
}

extension Color {
    /// 0xRRGGBB.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

#Preview("Stages") {
    HStack {
        ForEach(BabyStage.allCases, id: \.self) { stage in
            VStack {
                BabyAvatarView(stage: stage, outfit: BabyCatalog.item(id: "outfit.bunny"), size: 90)
                Text(stage.title).font(.caption)
            }
        }
    }
    .padding()
}
