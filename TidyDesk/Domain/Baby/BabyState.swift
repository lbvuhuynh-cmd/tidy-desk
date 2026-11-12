import Foundation

/// What a desk clear pays into Baby Corner.
struct BabyReward: Equatable {
    var coins: Int
    var growth: Int
    /// Set when this reward made the baby reach a new stage.
    var grewTo: BabyStage?

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
    /// Tummy (food) or joy (toy) is already full: the baby is content. Tidy a desk and come back.
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

/// Baby Corner rules as a plain value, so they are unit-tested without SwiftData or UI.
///
/// Kid-friendly by design:
/// * **Nothing decays with real time.** The baby never gets hungry or sad because the player was away.
///   Tummy and joy only go down a little when a desk is cleared ("the baby got peckish while you tidied"),
///   and never below `needsFloor`, so the baby always looks fine.
/// * Coins only come from playing and are never taken away. Growth only goes up.
struct BabyState: Equatable {
    static let maxNeed = 100.0
    /// Tummy and joy never drop below this.
    static let needsFloor = 25.0
    /// How much tummy / joy a desk clear uses up.
    static let needsPerClear = 12.0
    /// Welcome gift so the first visit already lets the player feed and dress the baby.
    static let startingCoins = 20

    var coins = BabyState.startingCoins
    var growthPoints = 0
    var tummy = 50.0
    var joy = 50.0
    var equippedOutfitId = BabyCatalog.defaultOutfitId
    var unlockedItemIds: Set<String> = BabyCatalog.starterItemIds

    var stage: BabyStage { .stage(for: growthPoints) }
    var stageProgress: Double { BabyStage.progress(for: growthPoints) }
    var equippedOutfit: BabyShopItem? { BabyCatalog.item(id: equippedOutfitId) }

    /// The baby "asks" for food or play when that need is low (shown as a little thought bubble, never as crying).
    var wantsFood: Bool { tummy < 50 }
    var wantsPlay: Bool { joy < 50 }

    func owns(_ item: BabyShopItem) -> Bool { item.price == 0 || unlockedItemIds.contains(item.id) }

    // MARK: Rewards

    /// Pays the desk-clear reward and uses up a bit of tummy / joy.
    @discardableResult
    mutating func applyClear(stars: Int, isFirstClear: Bool) -> BabyReward {
        var reward = BabyReward.forClear(stars: stars, isFirstClear: isFirstClear)
        coins += reward.coins
        reward.grewTo = grow(by: reward.growth)
        tummy = max(Self.needsFloor, tummy - Self.needsPerClear)
        joy = max(Self.needsFloor, joy - Self.needsPerClear)
        return reward
    }

    // MARK: Care

    /// Buys one portion and feeds it right away.
    mutating func feed(_ food: BabyShopItem) -> CareResult {
        guard food.kind == .food else { return .invalid }
        guard stage >= food.minStage else { return .tooYoung(needs: food.minStage) }
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
        guard joy < Self.maxNeed else { return .alreadyFull }
        joy = min(Self.maxNeed, joy + toy.fill)
        return .done(grewTo: grow(by: toy.growth))
    }

    /// Buys a toy or an outfit (once).
    mutating func buy(_ item: BabyShopItem) -> CareResult {
        guard item.kind != .food else { return .invalid }
        guard !owns(item) else { return .alreadyOwned }
        guard stage >= item.minStage else { return .tooYoung(needs: item.minStage) }
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

    /// Adds growth; returns the new stage when one was reached.
    private mutating func grow(by points: Int) -> BabyStage? {
        let before = stage
        growthPoints += max(0, points)
        return stage > before ? stage : nil
    }
}
