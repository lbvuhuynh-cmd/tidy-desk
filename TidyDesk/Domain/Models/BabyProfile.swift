import Foundation
import SwiftData

/// Baby Corner save data (SwiftData, local only). There is one profile per install; `BabyStore.profile(in:)`
/// creates it on first use. The rules live in `BabyState`; this model only stores the values.
@Model
final class BabyProfile {
    /// Empty until the player names the baby (the nursery asks on the first visit).
    var name: String = ""
    var coins: Int = BabyState.startingCoins
    var growthPoints: Int = 0
    /// 0–100. Tummy (spec: "hunger", higher = fuller).
    var hunger: Double = 50
    /// 0–100.
    var happiness: Double = 50
    var equippedOutfit: String = BabyCatalog.defaultOutfitId
    var unlockedItemIds: [String] = Array(BabyCatalog.starterItemIds).sorted()
    var createdAt: Date = Date.now

    init(name: String = "", state: BabyState = BabyState(), createdAt: Date = .now) {
        self.name = name
        self.coins = state.coins
        self.growthPoints = state.growthPoints
        self.hunger = state.tummy
        self.happiness = state.joy
        self.equippedOutfit = state.equippedOutfitId
        self.unlockedItemIds = state.unlockedItemIds.sorted()
        self.createdAt = createdAt
    }

    /// The rules view of the stored values.
    var state: BabyState {
        get {
            BabyState(coins: coins, growthPoints: growthPoints, tummy: hunger, joy: happiness,
                      equippedOutfitId: equippedOutfit,
                      unlockedItemIds: Set(unlockedItemIds).union(BabyCatalog.starterItemIds))
        }
        set {
            coins = newValue.coins
            growthPoints = newValue.growthPoints
            hunger = newValue.tummy
            happiness = newValue.joy
            equippedOutfit = newValue.equippedOutfitId
            unlockedItemIds = newValue.unlockedItemIds.sorted()
        }
    }

    var stage: BabyStage { state.stage }
    var displayName: String { name.isEmpty ? "Baby" : name }

    /// Runs a rule on the state and saves the result.
    @discardableResult
    func update<R>(_ change: (inout BabyState) -> R) -> R {
        var copy = state
        let result = change(&copy)
        if copy != state { state = copy }
        return result
    }
}

enum BabyStore {
    /// The single profile, created on first use.
    @MainActor
    static func profile(in context: ModelContext) -> BabyProfile {
        var descriptor = FetchDescriptor<BabyProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first { return existing }
        let profile = BabyProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }

    /// Pays a desk clear into Baby Corner and saves.
    @MainActor
    @discardableResult
    static func rewardClear(stars: Int, isFirstClear: Bool, in context: ModelContext) -> BabyReward {
        let profile = profile(in: context)
        let reward = profile.update { $0.applyClear(stars: stars, isFirstClear: isFirstClear) }
        try? context.save()
        return reward
    }
}
