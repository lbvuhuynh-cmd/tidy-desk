import Foundation

/// The baby's growth stages in Baby Corner. Growth points come from clearing desks and from caring for the baby;
/// they never go down, so the baby only ever grows (no punishment for being away).
enum BabyStage: Int, CaseIterable, Comparable, Codable {
    /// Swaddled, sleepy, needs milk and cuddles.
    case newborn
    /// Smiles and reacts to rattles and toys.
    case infant
    /// Crawls around the play mat.
    case crawler
    /// First wobbly steps, more toys and outfits.
    case toddler

    /// Growth points needed to reach this stage.
    var threshold: Int {
        switch self {
        case .newborn: 0
        case .infant: 60
        case .crawler: 180
        case .toddler: 360
        }
    }

    var title: String {
        switch self {
        case .newborn: "Newborn"
        case .infant: "Little Smiler"
        case .crawler: "Crawler"
        case .toddler: "Toddler"
        }
    }

    /// Asset name for real artwork (`baby_newborn` …). Until it exists the avatar is drawn in code.
    var assetName: String { "baby_\(String(describing: self))" }

    var next: BabyStage? { BabyStage(rawValue: rawValue + 1) }

    static func stage(for growthPoints: Int) -> BabyStage {
        allCases.last { growthPoints >= $0.threshold } ?? .newborn
    }

    /// 0…1 progress from this stage's threshold to the next one (1 at the last stage).
    static func progress(for growthPoints: Int) -> Double {
        let stage = stage(for: growthPoints)
        guard let next = stage.next else { return 1 }
        let span = Double(next.threshold - stage.threshold)
        return min(1, max(0, Double(growthPoints - stage.threshold) / span))
    }

    static func < (lhs: BabyStage, rhs: BabyStage) -> Bool { lhs.rawValue < rhs.rawValue }
}
