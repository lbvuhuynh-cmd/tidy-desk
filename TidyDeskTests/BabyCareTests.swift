import XCTest
import SwiftData
@testable import TidyDesk

final class BabyStageTests: XCTestCase {
    func testStagesFollowGrowthThresholds() {
        XCTAssertEqual(BabyStage.stage(for: 0), .newborn)
        XCTAssertEqual(BabyStage.stage(for: 59), .newborn)
        XCTAssertEqual(BabyStage.stage(for: 60), .infant)
        XCTAssertEqual(BabyStage.stage(for: 180), .crawler)
        XCTAssertEqual(BabyStage.stage(for: 359), .crawler)
        XCTAssertEqual(BabyStage.stage(for: 360), .toddler)
        XCTAssertEqual(BabyStage.stage(for: 10_000), .toddler)
    }

    func testThresholdsGrowAndProgressStaysInRange() {
        let thresholds = BabyStage.allCases.map(\.threshold)
        XCTAssertEqual(thresholds, thresholds.sorted())
        XCTAssertEqual(Set(thresholds).count, thresholds.count)
        XCTAssertEqual(BabyStage.progress(for: 0), 0)
        XCTAssertEqual(BabyStage.progress(for: 30), 0.5, accuracy: 0.001)   // halfway newborn -> infant (0…60)
        XCTAssertEqual(BabyStage.progress(for: 120), 0.5, accuracy: 0.001)  // halfway infant -> crawler (60…180)
        XCTAssertEqual(BabyStage.progress(for: 999), 1)                     // last stage
    }
}

final class BabyRewardTests: XCTestCase {
    func testFirstClearPaysMoreThanAReplay() {
        for stars in 1...3 {
            let first = BabyReward.forClear(stars: stars, isFirstClear: true)
            let replay = BabyReward.forClear(stars: stars, isFirstClear: false)
            XCTAssertGreaterThan(first.coins, replay.coins)
            XCTAssertGreaterThan(first.growth, replay.growth)
            XCTAssertGreaterThan(replay.coins, 0, "replays still pay something")
        }
        XCTAssertEqual(BabyReward.forClear(stars: 3, isFirstClear: true), BabyReward(coins: 25, growth: 30))
        XCTAssertEqual(BabyReward.forClear(stars: 1, isFirstClear: false), BabyReward(coins: 4, growth: 3))
    }

    func testMoreStarsPayMoreAndStarsAreClamped() {
        let one = BabyReward.forClear(stars: 1, isFirstClear: true)
        let three = BabyReward.forClear(stars: 3, isFirstClear: true)
        XCTAssertGreaterThan(three.coins, one.coins)
        XCTAssertEqual(BabyReward.forClear(stars: 0, isFirstClear: true), one)
        XCTAssertEqual(BabyReward.forClear(stars: 7, isFirstClear: true), three)
    }

    func testClearAddsCoinsAndGrowthAndUsesUpABitOfTummyAndJoy() {
        var state = BabyState()
        let reward = state.applyClear(stars: 3, isFirstClear: true)
        XCTAssertEqual(state.coins, BabyState.startingCoins + reward.coins)
        XCTAssertEqual(state.growthPoints, reward.growth)
        XCTAssertEqual(state.tummy, 50 - BabyState.needsPerClear)
        XCTAssertEqual(state.joy, 50 - BabyState.needsPerClear)
    }

    /// Kid-friendly: needs never drop below the floor, however many desks are cleared in a row.
    func testNeedsNeverDropBelowTheFloor() {
        var state = BabyState()
        for _ in 0..<20 { state.applyClear(stars: 1, isFirstClear: false) }
        XCTAssertEqual(state.tummy, BabyState.needsFloor)
        XCTAssertEqual(state.joy, BabyState.needsFloor)
    }

    func testClearReportsTheNewStage() {
        var state = BabyState()
        state.growthPoints = 50
        let reward = state.applyClear(stars: 1, isFirstClear: true) // +10 -> 60 = infant
        XCTAssertEqual(reward.grewTo, .infant)
        XCTAssertNil(state.applyClear(stars: 1, isFirstClear: false).grewTo)
    }
}

final class BabyCareTests: XCTestCase {
    private func item(_ id: String) -> BabyShopItem {
        guard let item = BabyCatalog.item(id: id) else {
            XCTFail("missing \(id)")
            return BabyCatalog.items[0]
        }
        return item
    }

    func testFeedingCostsCoinsFillsTummyAndGrows() {
        var state = BabyState()
        let milk = item("food.milk")
        XCTAssertEqual(state.feed(milk), .done(grewTo: nil))
        XCTAssertEqual(state.coins, BabyState.startingCoins - milk.price)
        XCTAssertEqual(state.tummy, 50 + milk.fill)
        XCTAssertEqual(state.growthPoints, milk.growth)
    }

    func testFullBabyDoesNotEatAndKeepsTheCoins() {
        var state = BabyState()
        state.tummy = BabyState.maxNeed
        XCTAssertEqual(state.feed(item("food.milk")), .alreadyFull)
        XCTAssertEqual(state.coins, BabyState.startingCoins)
        state.tummy = 90
        XCTAssertTrue(state.feed(item("food.milk")).isDone)
        XCTAssertEqual(state.tummy, BabyState.maxNeed, "tummy is capped at 100")
    }

    func testNotEnoughCoinsSaysHowManyAreMissing() {
        var state = BabyState()
        state.coins = 1
        XCTAssertEqual(state.feed(item("food.milk")), .notEnoughCoins(missing: 3))
        XCTAssertEqual(state.coins, 1)
        XCTAssertEqual(state.tummy, 50)
    }

    func testFoodForOlderBabiesIsLocked() {
        var state = BabyState()
        XCTAssertEqual(state.feed(item("food.porridge")), .tooYoung(needs: .infant))
        state.growthPoints = BabyStage.infant.threshold
        XCTAssertTrue(state.feed(item("food.porridge")).isDone)
    }

    func testToysAreBoughtOnceThenFreeToPlay() {
        var state = BabyState()
        let duck = item("toy.duck")
        XCTAssertEqual(state.play(with: duck), .notOwned)
        XCTAssertEqual(state.buy(duck), .done(grewTo: nil))
        XCTAssertEqual(state.coins, BabyState.startingCoins - duck.price)
        XCTAssertEqual(state.buy(duck), .alreadyOwned)
        let coins = state.coins
        XCTAssertTrue(state.play(with: duck).isDone)
        XCTAssertEqual(state.coins, coins, "playing with an owned toy is free")
        XCTAssertEqual(state.joy, 50 + duck.fill)
    }

    func testStarterRattleIsOwnedAndPlayStopsWhenJoyIsFull() {
        var state = BabyState()
        let rattle = item("toy.rattle")
        XCTAssertTrue(state.owns(rattle))
        var plays = 0
        while state.play(with: rattle).isDone { plays += 1 }
        XCTAssertEqual(state.joy, BabyState.maxNeed)
        XCTAssertEqual(plays, 2, "50 -> 80 -> 100, then the baby is content")
        XCTAssertEqual(state.play(with: rattle), .alreadyFull)
        XCTAssertEqual(state.growthPoints, rattle.growth * plays, "free play can't farm growth")
    }

    func testOutfitsBuyAndWear() {
        var state = BabyState()
        let bunny = item("outfit.bunny")
        XCTAssertEqual(state.equippedOutfitId, BabyCatalog.defaultOutfitId)
        XCTAssertEqual(state.wear(bunny), .notOwned)
        XCTAssertTrue(state.buy(bunny).isDone)
        XCTAssertTrue(state.wear(bunny).isDone)
        XCTAssertEqual(state.equippedOutfitId, "outfit.bunny")
        XCTAssertTrue(state.wear(item(BabyCatalog.defaultOutfitId)).isDone, "the starter onesie is always available")
    }

    func testBuyingRespectsStageAndCoins() {
        var state = BabyState()
        XCTAssertEqual(state.buy(item("outfit.bear")), .tooYoung(needs: .infant))
        state.growthPoints = BabyStage.infant.threshold
        state.coins = 10
        XCTAssertEqual(state.buy(item("outfit.bear")), .notEnoughCoins(missing: 30))
        XCTAssertFalse(state.unlockedItemIds.contains("outfit.bear"))
    }

    func testWrongKindIsRejected() {
        var state = BabyState()
        XCTAssertEqual(state.feed(item("toy.duck")), .invalid)
        XCTAssertEqual(state.play(with: item("food.milk")), .invalid)
        XCTAssertEqual(state.buy(item("food.milk")), .invalid)
        XCTAssertEqual(state.wear(item("toy.duck")), .invalid)
    }

    func testCareCanGrowTheBaby() {
        var state = BabyState()
        state.growthPoints = BabyStage.infant.threshold - 1
        XCTAssertEqual(state.feed(item("food.milk")), .done(grewTo: .infant))
        XCTAssertEqual(state.stage, .infant)
    }

    func testCatalogIsConsistent() {
        let ids = BabyCatalog.items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "ids are unique")
        XCTAssertNotNil(BabyCatalog.item(id: BabyCatalog.defaultOutfitId))
        XCTAssertTrue(BabyCatalog.starterItemIds.contains(BabyCatalog.defaultOutfitId))
        XCTAssertFalse(BabyCatalog.items(of: .food).isEmpty)
        XCTAssertFalse(BabyCatalog.items(of: .toy).filter { $0.price == 0 }.isEmpty, "a free toy to start with")
        for food in BabyCatalog.items(of: .food) {
            XCTAssertGreaterThan(food.price, 0, food.id)
            XCTAssertLessThanOrEqual(food.price, BabyState.startingCoins, "\(food.id): affordable from the welcome gift")
            XCTAssertGreaterThan(food.fill, 0, food.id)
        }
        for item in BabyCatalog.items {
            XCTAssertFalse(item.emoji.isEmpty, item.id)
            XCTAssertTrue(item.price == 0 ? item.minStage == .newborn : true, "\(item.id): free items are for every age")
        }
    }
}

@MainActor
final class BabyStoreTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: LevelProgress.self, BabyProfile.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testProfileIsCreatedOnceWithStarterValues() throws {
        let context = try makeContext()
        let profile = BabyStore.profile(in: context)
        XCTAssertTrue(BabyStore.profile(in: context) === profile)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BabyProfile>()), 1)
        XCTAssertEqual(profile.state, BabyState())
        XCTAssertEqual(profile.displayName, "Baby")
    }

    func testRewardClearIsSaved() throws {
        let context = try makeContext()
        let reward = BabyStore.rewardClear(stars: 2, isFirstClear: true, in: context)
        let profile = BabyStore.profile(in: context)
        XCTAssertEqual(profile.coins, BabyState.startingCoins + reward.coins)
        XCTAssertEqual(profile.growthPoints, reward.growth)
    }

    func testUpdateWritesTheRuleResultBack() throws {
        let context = try makeContext()
        let profile = BabyStore.profile(in: context)
        let duck = try XCTUnwrap(BabyCatalog.item(id: "toy.duck"))
        XCTAssertTrue(profile.update { $0.buy(duck) }.isDone)
        XCTAssertTrue(profile.unlockedItemIds.contains("toy.duck"))
        XCTAssertEqual(profile.coins, BabyState.startingCoins - duck.price)
    }

    func testFirstClearIsToldApartFromAReplay() throws {
        let context = try makeContext()
        XCTAssertFalse(ProgressStore.isCompleted(levelId: 1, in: context))
        ProgressStore.recordClear(levelId: 1, moves: 3, stars: 3, seconds: 10, score: 300, in: context)
        XCTAssertTrue(ProgressStore.isCompleted(levelId: 1, in: context))
        XCTAssertFalse(ProgressStore.isCompleted(levelId: 2, in: context))
    }
}
