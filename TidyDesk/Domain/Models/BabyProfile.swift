import Foundation
import SwiftData

/// Baby Corner save data (SwiftData, local only). There is one profile per install; `BabyStore.profile(in:)`
/// creates it on first use. Age in months, stage and milestones all derive from `growthPoints` (see `BabyGrowth`). The rules live in `BabyState`; this model only stores the values.
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
    // Added with months / Baby Book / bath / sleep (defaults let SwiftData migrate older saves).
    /// 0–100.
    var cleanliness: Double = 70
    /// 0–100.
    var rest: Double = 70
    /// Baby Book: reached milestone ids and, at the same index, when they were reached.
    var milestoneIds: [String] = []
    var milestoneDates: [Date] = []
    var firstWord: String = ""

    init(name: String = "", state: BabyState = BabyState(), createdAt: Date = .now) {
        self.name = name
        self.coins = state.coins
        self.growthPoints = state.growthPoints
        self.hunger = state.tummy
        self.happiness = state.joy
        self.equippedOutfit = state.equippedOutfitId
        self.unlockedItemIds = state.unlockedItemIds.sorted()
        self.createdAt = createdAt
        self.cleanliness = state.clean
        self.rest = state.rest
        let log = Self.log(state.milestoneDates)
        self.milestoneIds = log.ids
        self.milestoneDates = log.dates
        self.firstWord = state.firstWord
    }

    /// Dictionary → two parallel arrays (plain arrays store reliably in SwiftData), sorted by date then id.
    private static func log(_ dates: [String: Date]) -> (ids: [String], dates: [Date]) {
        let sorted = dates.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value }
        return (sorted.map { $0.key }, sorted.map { $0.value })
    }

    /// The rules view of the stored values.
    var state: BabyState {
        get {
            var dates: [String: Date] = [:]
            for (index, id) in milestoneIds.enumerated() where index < milestoneDates.count {
                dates[id] = milestoneDates[index]
            }
            var value = BabyState()
            value.coins = coins
            value.growthPoints = growthPoints
            value.tummy = hunger
            value.joy = happiness
            value.clean = cleanliness
            value.rest = rest
            value.equippedOutfitId = equippedOutfit
            value.unlockedItemIds = Set(unlockedItemIds).union(BabyCatalog.starterItemIds)
            value.milestoneDates = dates
            value.firstWord = firstWord
            value.unlockEverything = BetaConfig.unlockAllBabyContent
            return value
        }
        set {
            coins = newValue.coins
            growthPoints = newValue.growthPoints
            hunger = newValue.tummy
            happiness = newValue.joy
            equippedOutfit = newValue.equippedOutfitId
            unlockedItemIds = newValue.unlockedItemIds.sorted()
            cleanliness = newValue.clean
            rest = newValue.rest
            let log = Self.log(newValue.milestoneDates)
            if log.ids != milestoneIds || log.dates != milestoneDates {
                milestoneIds = log.ids
                milestoneDates = log.dates
            }
            firstWord = newValue.firstWord
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
        let profile: BabyProfile
        if let existing = try? context.fetch(descriptor).first {
            profile = existing
        } else {
            profile = BabyProfile()
            context.insert(profile)
        }
        // "Hello" page for a new baby; older saves catch up on milestones for their age (no celebration).
        let caughtUp = profile.update { $0.recordMilestones() }
        if !caughtUp.isEmpty || context.hasChanges { try? context.save() }
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
