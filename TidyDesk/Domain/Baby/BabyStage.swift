import Foundation

/// Age in months, derived from growth points (which only ever go up: no punishment for being away).
///
/// Early months pass quickly (lots of firsts early on), later ones take longer, so the baby keeps growing
/// across all chapters: about 20 points per month in the first year, 35 in the second, 50 in the third.
/// A first desk clear pays 10–30 growth, so the first birthday comes after roughly 10 desks and the
/// third after the whole game plus some care.
enum BabyGrowth {
    static let maxMonths = 36

    /// Growth points it takes to get from `month` to `month + 1`.
    static func pointsPerMonth(_ month: Int) -> Int {
        switch month {
        case ..<12: 20
        case ..<24: 35
        default: 50
        }
    }

    /// Growth points needed to be `month` months old (0 → 0, 2 → 40, 12 → 240, 36 → 1260).
    static func threshold(month: Int) -> Int {
        let m = min(max(0, month), maxMonths)
        return (0..<m).reduce(0) { $0 + pointsPerMonth($1) }
    }

    /// Age in whole months (0…36).
    static func months(for points: Int) -> Int {
        var month = 0
        while month < maxMonths && points >= threshold(month: month + 1) { month += 1 }
        return month
    }

    /// 0…1 through the current month (1 at 36 months).
    static func monthProgress(for points: Int) -> Double {
        let month = months(for: points)
        guard month < maxMonths else { return 1 }
        let start = threshold(month: month)
        return min(1, max(0, Double(points - start) / Double(pointsPerMonth(month))))
    }

    /// "Just born", "1 month", "5 months", "2 years", "2½ years", "3 years".
    static func ageText(months: Int) -> String {
        switch months {
        case ..<1: "Just born"
        case 1: "1 month"
        case ..<24: "\(months) months"
        case ..<30: "2 years"
        case ..<36: "2½ years"
        default: "3 years"
        }
    }
}

/// The baby's growth stages in Baby Corner, by age in months. Each stage changes how the baby looks and
/// unlocks new food, toys and outfits.
enum BabyStage: Int, CaseIterable, Comparable, Codable {
    /// 0–2 months: swaddled, sleepy, needs milk and cuddles.
    case newborn
    /// 2–4 months: first smiles and giggles.
    case infant
    /// 4–6 months: rolls over, tummy time, first porridge.
    case roller
    /// 6–9 months: sits and crawls, first tooth.
    case crawler
    /// 9–18 months: stands, first steps, first word.
    case toddler
    /// 18–36 months: runs, talks, draws.
    case explorer

    /// Age (months) at which this stage starts.
    var startMonth: Int {
        switch self {
        case .newborn: 0
        case .infant: 2
        case .roller: 4
        case .crawler: 6
        case .toddler: 9
        case .explorer: 18
        }
    }

    /// Growth points needed to reach this stage.
    var threshold: Int { BabyGrowth.threshold(month: startMonth) }

    var title: String {
        switch self {
        case .newborn: "Newborn"
        case .infant: "Little Smiler"
        case .roller: "Little Roller"
        case .crawler: "Crawler"
        case .toddler: "Toddler"
        case .explorer: "Little Explorer"
        }
    }

    /// Asset name for real artwork (`baby_newborn` …). Until it exists the avatar is drawn in code.
    var assetName: String { "baby_\(String(describing: self))" }

    var next: BabyStage? { BabyStage(rawValue: rawValue + 1) }

    static func stage(forMonths months: Int) -> BabyStage {
        allCases.last { months >= $0.startMonth } ?? .newborn
    }

    static func stage(for growthPoints: Int) -> BabyStage {
        stage(forMonths: BabyGrowth.months(for: growthPoints))
    }

    /// 0…1 progress from this stage's threshold to the next one (1 at the last stage).
    static func progress(for growthPoints: Int) -> Double {
        let stage = stage(for: growthPoints)
        let end = stage.next?.threshold ?? BabyGrowth.threshold(month: BabyGrowth.maxMonths)
        let span = Double(end - stage.threshold)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(growthPoints - stage.threshold) / span))
    }

    static func < (lhs: BabyStage, rhs: BabyStage) -> Bool { lhs.rawValue < rhs.rawValue }
}
