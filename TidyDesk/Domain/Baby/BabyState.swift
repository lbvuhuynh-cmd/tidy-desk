import Foundation

/// What a desk clear pays into Baby Corner.
struct BabyReward: Equatable {
    var coins: Int
    var growth: Int
    /// Set when this reward made the baby reach a new stage.
    var grewTo: BabyStage?
    /// Milestones (Baby Book pages) reached thanks to this reward.
    var newMilestones: [BabyMilestone] = []

    /// First clear pays well; replays still pay a little (so kids can always earn), but not enough to farm.
    static func forClear(stars: Int, isFirstClear: Bool) -> BabyReward {
        let stars = min(3, max(1, stars))
        return isFirstClear
            ? BabyReward(coins: 10 + 5 * stars, growth: 10 * stars)
            : BabyReward(coins: 2 + 2 * stars, growth: 3 * stars)
    }
}

/// Outcome of a care action in the nursery.
enum CareResult: Equatable {
    /// Done. `grewTo` is set when the action made the baby reach a new stage.
    case done(grewTo: BabyStage?)
    case notEnoughCoins(missing: Int)
    /// That need is already full: the baby is content. Tidy a desk and come back.
    case alreadyFull
    /// The baby is too young for this item.
    case tooYoung(needs: BabyStage)
    /// Toy / outfit not bought yet.
    case notOwned
    /// Buying something already owned.
    case alreadyOwned
    /// Unknown id or wrong kind of item for the action.
    case invalid

    var isDone: Bool { if case .done = self { true } else { false } }
}

/// The four needs shown as meters in the nursery.
enum BabyNeed: CaseIterable {
    case tummy, joy, clean, rest

    var emoji: String {
        switch self {
        case .tummy: "🍼"
        case .joy: "💗"
        case .clean: "🫧"
        case .rest: "💤"
        }
    }

    var title: String {
        switch self {
        case .tummy: "Tummy"
        case .joy: "Joy"
        case .clean: "Clean"
        case .rest: "Sleep"
        }
    }
}

/// Baby Corner rules as a plain value, so they are unit-tested without SwiftData or UI.
///
/// Kid-friendly by design:
/// * **Nothing decays with real time.** The baby never gets hungry, dirty, tired or sad because the player was
///   away. Needs only go down a little when a desk is cleared ("the baby got peckish while you tidied"),
///   and never below `needsFloor`, so the baby always looks fine.
/// * Coins only come from playing and are never taken away. Growth (age) only goes up.
/// * Bath and sleep are free, so a child with no coins can still care for the baby.
struct BabyState: Equatable {
    static let maxNeed = 100.0
    /// Needs never drop below this.
    static let needsFloor = 25.0
    /// How much tummy / joy a desk clear uses up.
    static let needsPerClear = 12.0
    /// How much clean / rest a desk clear uses up (a little slower than food and play).
    static let slowNeedsPerClear = 10.0
    /// Welcome gift so the first visit already lets the player feed and dress the baby.
    static let startingCoins = 20
    /// Growth for a bath (also a little joy: baths are fun) and for a nap.
    static let bathGrowth = 6
    static let bathJoy = 10.0
    static let sleepGrowth = 8

    var coins = BabyState.startingCoins
    var growthPoints = 0
    var tummy = 50.0
    var joy = 50.0
    var clean = 70.0
    var rest = 70.0
    var equippedOutfitId = BabyCatalog.defaultOutfitId
    var unlockedItemIds: Set<String> = BabyCatalog.starterItemIds
    /// Milestone id → when it was reached (the Baby Book). "Hello" (month 0) is recorded when the profile is
    /// first loaded (`BabyStore.profile`), or on the first growth.
    var milestoneDates: [String: Date] = [:]
    /// What the baby said at the "First Word" milestone (empty until the player picks).
    var firstWord = ""
    /// TestFlight (`BetaConfig.unlockAllBabyContent`): every item is owned and no age locks apply.
    /// Not saved; `BabyProfile.state` sets it.
    var unlockEverything = false

    var months: Int { BabyGrowth.months(for: growthPoints) }
    var monthProgress: Double { BabyGrowth.monthProgress(for: growthPoints) }
    var stage: BabyStage { .stage(for: growthPoints) }
    var stageProgress: Double { BabyStage.progress(for: growthPoints) }
    var equippedOutfit: BabyShopItem? { BabyCatalog.item(id: equippedOutfitId) }

    func value(of need: BabyNeed) -> Double {
        switch need {
        case .tummy: tummy
        case .joy: joy
        case .clean: clean
        case .rest: rest
        }
    }

    /// The baby "asks" for something when that need is low (a little thought bubble, never crying).
    var wantsFood: Bool { tummy < 50 }
    var wantsPlay: Bool { joy < 50 }
    var wantsBath: Bool { clean < 50 }
    var wantsSleep: Bool { rest < 50 }

    /// The one wish shown in the bubble: food first, then sleep, bath, play.
    var wish: BabyNeed? {
        if wantsFood { return .tummy }
        if wantsSleep { return .rest }
        if wantsBath { return .clean }
        if wantsPlay { return .joy }
        return nil
    }

    func owns(_ item: BabyShopItem) -> Bool {
        unlockEverything || item.price == 0 || unlockedItemIds.contains(item.id)
    }

    func isOldEnough(for item: BabyShopItem) -> Bool { unlockEverything || stage >= item.minStage }

    /// Reached milestones, in age order.
    var reachedMilestones: [BabyMilestone] { BabyMilestones.all.filter { milestoneDates[$0.id] != nil } }

    // MARK: Rewards

    /// Pays the desk-clear reward and uses up a bit of every need.
    @discardableResult
    mutating func applyClear(stars: Int, isFirstClear: Bool, now: Date = .now) -> BabyReward {
        var reward = BabyReward.forClear(stars: stars, isFirstClear: isFirstClear)
        coins += reward.coins
        let before = Set(milestoneDates.keys)
        reward.grewTo = grow(by: reward.growth, now: now)
        reward.newMilestones = BabyMilestones.all.filter { milestoneDates[$0.id] != nil && !before.contains($0.id) }
        tummy = max(Self.needsFloor, tummy - Self.needsPerClear)
        joy = max(Self.needsFloor, joy - Self.needsPerClear)
        clean = max(Self.needsFloor, clean - Self.slowNeedsPerClear)
        rest = max(Self.needsFloor, rest - Self.slowNeedsPerClear)
        return reward
    }

    // MARK: Care

    /// Buys one portion and feeds it right away.
    mutating func feed(_ food: BabyShopItem) -> CareResult {
        guard food.kind == .food else { return .invalid }
        guard isOldEnough(for: food) else { return .tooYoung(needs: food.minStage) }
        guard tummy < Self.maxNeed else { return .alreadyFull }
        guard coins >= food.price else { return .notEnoughCoins(missing: food.price - coins) }
        coins -= food.price
        tummy = min(Self.maxNeed, tummy + food.fill)
        return .done(grewTo: grow(by: food.growth))
    }

    /// Plays with an owned toy (free).
    mutating func play(with toy: BabyShopItem) -> CareResult {
        guard toy.kind == .toy else { return .invalid }
        guard owns(toy) else { return .notOwned }
        guard isOldEnough(for: toy) else { return .tooYoung(needs: toy.minStage) }
        guard joy < Self.maxNeed else { return .alreadyFull }
        joy = min(Self.maxNeed, joy + toy.fill)
        return .done(grewTo: grow(by: toy.growth))
    }

    /// Bath time (free): squeaky clean, a bit of joy, a bit of growth.
    mutating func bathe() -> CareResult {
        guard clean < Self.maxNeed else { return .alreadyFull }
        clean = Self.maxNeed
        joy = min(Self.maxNeed, joy + Self.bathJoy)
        return .done(grewTo: grow(by: Self.bathGrowth))
    }

    /// Rocked to sleep (free): fully rested, a bit of growth ("babies grow while they sleep").
    mutating func sleep() -> CareResult {
        guard rest < Self.maxNeed else { return .alreadyFull }
        rest = Self.maxNeed
        return .done(grewTo: grow(by: Self.sleepGrowth))
    }

    /// Buys a toy or an outfit (once).
    mutating func buy(_ item: BabyShopItem) -> CareResult {
        guard item.kind != .food else { return .invalid }
        guard !owns(item) else { return .alreadyOwned }
        guard isOldEnough(for: item) else { return .tooYoung(needs: item.minStage) }
        guard coins >= item.price else { return .notEnoughCoins(missing: item.price - coins) }
        coins -= item.price
        unlockedItemIds.insert(item.id)
        return .done(grewTo: nil)
    }

    /// Puts on an owned outfit.
    mutating func wear(_ outfit: BabyShopItem) -> CareResult {
        guard outfit.kind == .outfit else { return .invalid }
        guard owns(outfit) else { return .notOwned }
        equippedOutfitId = outfit.id
        return .done(grewTo: nil)
    }

    // MARK: Milestones

    /// Records every milestone the baby is old enough for but doesn't have yet. Returns the new ones.
    /// Runs after any growth, and once on load (profiles saved before milestones existed catch up silently).
    @discardableResult
    mutating func recordMilestones(now: Date = .now) -> [BabyMilestone] {
        let age = months
        let fresh = BabyMilestones.all.filter { $0.month <= age && milestoneDates[$0.id] == nil }
        for milestone in fresh { milestoneDates[milestone.id] = now }
        return fresh
    }

    /// TestFlight only: jump to any age (also backwards). Milestones past the new age are removed so they can be
    /// celebrated again; the ones reached by the jump are returned.
    @discardableResult
    mutating func setAgeForTesting(months: Int, now: Date = .now) -> [BabyMilestone] {
        let target = min(max(0, months), BabyGrowth.maxMonths)
        growthPoints = BabyGrowth.threshold(month: target)
        for milestone in BabyMilestones.all where milestone.month > target {
            milestoneDates[milestone.id] = nil
        }
        return recordMilestones(now: now)
    }

    /// Adds growth (and records milestones); returns the new stage when one was reached.
    private mutating func grow(by points: Int, now: Date = .now) -> BabyStage? {
        let before = stage
        growthPoints += max(0, points)
        recordMilestones(now: now)
        return stage > before ? stage : nil
    }
}
