import Foundation

/// A real-world good deed or habit a child can be rewarded for (exercise, helping at home, school, kindness).
/// A grown-up confirms each one (`ParentGateView`), and it pays coins (and a little growth) into Baby Corner,
/// so good habits outside the game feed the baby inside it.
///
/// Kept deliberately light and private: only "which deed, which day" is stored on the device, never details
/// (no grades, no names), and nothing leaves the phone.
struct GoodDeed: Identifiable, Equatable, Hashable {
    enum Category: String, CaseIterable {
        case health, chores, school, kindness

        var title: String {
            switch self {
            case .health: "Health & sports"
            case .chores: "Helping at home"
            case .school: "School"
            case .kindness: "Kindness"
            }
        }

        /// Soft pastel card colour (0xRRGGBB).
        var tint: UInt32 {
            switch self {
            case .health: 0xD7EFD9
            case .chores: 0xFCE6C8
            case .school: 0xD8E6FA
            case .kindness: 0xFADDE6
            }
        }
    }

    let id: String
    let title: String
    let emoji: String
    /// Short example under the title, written for kids.
    let detail: String
    let points: Int
    let category: Category
    /// How many times it can be ticked off per calendar day.
    let dailyLimit: Int

    /// Points convert 1:1 to Baby Corner coins…
    var coins: Int { points }
    /// …and half of them to growth (a desk clear gives 10–30), so habits help the baby grow without racing it.
    var growth: Int { points / 2 }
}

/// One ticked-off deed.
struct GoodDeedEntry: Equatable, Hashable {
    let deedId: String
    let date: Date
}

/// Outcome of ticking off a deed.
enum GoodDeedResult: Equatable {
    case done(BabyReward)
    /// Already ticked off `dailyLimit` times today: see you tomorrow.
    case dailyLimitReached
    case invalid

    var isDone: Bool { if case .done = self { true } else { false } }
}

enum GoodDeeds {
    static let exercise = GoodDeed(id: "deed.exercise", title: "Exercise or sports", emoji: "🏃",
                                   detail: "Ran, swam, danced, played ball", points: 10,
                                   category: .health, dailyLimit: 1)
    static let chores = GoodDeed(id: "deed.chores", title: "Helped at home", emoji: "🧹",
                                 detail: "Tidied up, set the table, fed the pet", points: 15,
                                 category: .chores, dailyLimit: 1)
    static let school = GoodDeed(id: "deed.school", title: "Good job at school", emoji: "📚",
                                 detail: "Good grade, homework done, read a book", points: 20,
                                 category: .school, dailyLimit: 1)
    static let kindness = GoodDeed(id: "deed.kindness", title: "Kind or shared", emoji: "💛",
                                   detail: "Shared, helped a friend, said sorry", points: 10,
                                   category: .kindness, dailyLimit: 2)

    static let all: [GoodDeed] = [exercise, chores, school, kindness]

    static func deed(id: String) -> GoodDeed? { all.first { $0.id == id } }

    /// Entries older than this are dropped when a new one is added (the sticker chart shows the last week).
    static let historyDays = 60
}

extension BabyState {
    /// Times `deed` was ticked off on the calendar day of `day`.
    func timesDone(_ deed: GoodDeed, on day: Date = .now, calendar: Calendar = .current) -> Int {
        goodDeeds.filter { $0.deedId == deed.id && calendar.isDate($0.date, inSameDayAs: day) }.count
    }

    /// Whether `deed` can be ticked off now. TestFlight (`unlockEverything`): no daily limit, for testing.
    func canDo(_ deed: GoodDeed, now: Date = .now, calendar: Calendar = .current) -> Bool {
        unlockEverything || timesDone(deed, on: now, calendar: calendar) < deed.dailyLimit
    }

    /// Deeds from the last 7 days (today included), oldest first: the "this week" sticker row.
    func goodDeedsThisWeek(now: Date = .now, calendar: Calendar = .current) -> [GoodDeedEntry] {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        return goodDeeds.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
    }

    /// Ticks off a deed a grown-up confirmed: pays coins + growth, and the baby is a bit happier.
    mutating func logGoodDeed(_ deed: GoodDeed, now: Date = .now, calendar: Calendar = .current) -> GoodDeedResult {
        guard GoodDeeds.deed(id: deed.id) != nil else { return .invalid }
        guard canDo(deed, now: now, calendar: calendar) else { return .dailyLimitReached }
        let cutoff = calendar.date(byAdding: .day, value: -GoodDeeds.historyDays, to: now) ?? now
        goodDeeds.removeAll { $0.date < cutoff }
        goodDeeds.append(GoodDeedEntry(deedId: deed.id, date: now))
        joy = min(Self.maxNeed, joy + Self.goodDeedJoy)
        return .done(pay(coins: deed.coins, growth: deed.growth, now: now))
    }
}
