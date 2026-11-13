import XCTest
import SwiftData
@testable import TidyDesk

final class BabyStageTests: XCTestCase {
    func testMonthsFollowTheGrowthCurve() {
        XCTAssertEqual(BabyGrowth.threshold(month: 0), 0)
        XCTAssertEqual(BabyGrowth.threshold(month: 2), 40)
        XCTAssertEqual(BabyGrowth.threshold(month: 12), 240)
        XCTAssertEqual(BabyGrowth.threshold(month: 24), 660)
        XCTAssertEqual(BabyGrowth.threshold(month: 36), 1260)
        XCTAssertEqual(BabyGrowth.months(for: 0), 0)
        XCTAssertEqual(BabyGrowth.months(for: 39), 1)
        XCTAssertEqual(BabyGrowth.months(for: 40), 2)
        XCTAssertEqual(BabyGrowth.months(for: 240), 12)
        XCTAssertEqual(BabyGrowth.months(for: 100_000), BabyGrowth.maxMonths)
        XCTAssertEqual(BabyGrowth.monthProgress(for: 10), 0.5, accuracy: 0.001)   // halfway through month 0 (20 pts)
        XCTAssertEqual(BabyGrowth.monthProgress(for: 100_000), 1)
    }

    /// Each month takes at least as long as the one before (early "firsts" come quickly).
    func testMonthsNeverGetShorter() {
        var previous = 0
        for month in 0..<BabyGrowth.maxMonths {
            XCTAssertGreaterThanOrEqual(BabyGrowth.pointsPerMonth(month), previous)
            previous = BabyGrowth.pointsPerMonth(month)
        }
    }

    func testSixStagesByAge() {
        XCTAssertEqual(BabyStage.allCases.count, 6)
        XCTAssertEqual(BabyStage.stage(forMonths: 0), .newborn)
        XCTAssertEqual(BabyStage.stage(forMonths: 1), .newborn)
        XCTAssertEqual(BabyStage.stage(forMonths: 2), .infant)
        XCTAssertEqual(BabyStage.stage(forMonths: 5), .roller)
        XCTAssertEqual(BabyStage.stage(forMonths: 6), .crawler)
        XCTAssertEqual(BabyStage.stage(forMonths: 9), .toddler)
        XCTAssertEqual(BabyStage.stage(forMonths: 17), .toddler)
        XCTAssertEqual(BabyStage.stage(forMonths: 18), .explorer)
        XCTAssertEqual(BabyStage.stage(forMonths: 36), .explorer)
        XCTAssertEqual(BabyStage.stage(for: BabyStage.crawler.threshold), .crawler)
        XCTAssertEqual(BabyStage.stage(for: BabyStage.crawler.threshold - 1), .roller)
    }

    func testThresholdsGrowAndProgressStaysInRange() {
        let thresholds = BabyStage.allCases.map(\.threshold)
        XCTAssertEqual(thresholds, thresholds.sorted())
        XCTAssertEqual(Set(thresholds).count, thresholds.count)
        XCTAssertEqual(BabyStage.progress(for: 0), 0)
        XCTAssertEqual(BabyStage.progress(for: 20), 0.5, accuracy: 0.001)   // halfway newborn -> infant (0…40)
        XCTAssertEqual(BabyStage.progress(for: 100_000), 1)
        for points in stride(from: 0, through: 1400, by: 7) {
            XCTAssertTrue((0...1).contains(BabyStage.progress(for: points)), "\(points)")
        }
    }

    func testAgeText() {
        XCTAssertEqual(BabyGrowth.ageText(months: 0), "Just born")
        XCTAssertEqual(BabyGrowth.ageText(months: 1), "1 month")
        XCTAssertEqual(BabyGrowth.ageText(months: 5), "5 months")
        XCTAssertEqual(BabyGrowth.ageText(months: 24), "2 years")
        XCTAssertEqual(BabyGrowth.ageText(months: 30), "2½ years")
        XCTAssertEqual(BabyGrowth.ageText(months: 36), "3 years")
    }
}

final class BabyMilestoneTests: XCTestCase {
    func testCatalogIsOrderedUniqueAndCoversEveryStage() {
        let ids = BabyMilestones.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        let months = BabyMilestones.all.map(\.month)
        XCTAssertEqual(months, months.sorted())
        XCTAssertEqual(months.first, 0)
        XCTAssertEqual(months.last, BabyGrowth.maxMonths)
        XCTAssertEqual(Set(BabyMilestones.all.map(\.stage)), Set(BabyStage.allCases), "every stage has a page")
        XCTAssertNotNil(BabyMilestones.milestone(id: BabyMilestones.firstWordId))
    }

    func testMilestonesAreRecordedAsTheBabyGrows() {
        var state = BabyState()
        XCTAssertTrue(state.reachedMilestones.isEmpty)
        XCTAssertEqual(state.recordMilestones().map(\.id), ["hello"])
        XCTAssertEqual(state.recordMilestones(), [], "recorded once")

        state.growthPoints = BabyGrowth.threshold(month: 2) - 5
        state.recordMilestones()
        let reward = state.applyClear(stars: 1, isFirstClear: true) // +10 -> month 2
        XCTAssertEqual(reward.grewTo, .infant)
        XCTAssertEqual(reward.newMilestones.map(\.id), ["first_smile"])
        XCTAssertNotNil(state.milestoneDates["first_smile"])
        XCTAssertEqual(state.applyClear(stars: 1, isFirstClear: false).newMilestones, [])
    }

    func testCareCanReachAMilestone() {
        var state = BabyState()
        state.growthPoints = BabyGrowth.threshold(month: 1) - 1
        XCTAssertTrue(state.sleep().isDone)
        XCTAssertNotNil(state.milestoneDates["first_gaze"])
    }

    func testTestingAgeJumpsBothWays() {
        var state = BabyState()
        let reached = state.setAgeForTesting(months: 12)
        XCTAssertEqual(state.months, 12)
        XCTAssertEqual(state.stage, .toddler)
        XCTAssertTrue(reached.contains { $0.id == "birthday_1" })
        XCTAssertEqual(state.reachedMilestones.count, BabyMilestones.all.filter { $0.month <= 12 }.count)

        state.setAgeForTesting(months: 3)
        XCTAssertEqual(state.months, 3)
        XCTAssertNil(state.milestoneDates["birthday_1"], "pages past the new age are removed")
        XCTAssertNotNil(state.milestoneDates["first_giggle"])
        XCTAssertEqual(state.setAgeForTesting(months: 99).last?.id, "birthday_3")
        XCTAssertEqual(state.months, BabyGrowth.maxMonths)
    }

    func testCaptionFillsNameAndFirstWord() throws {
        let word = try XCTUnwrap(BabyMilestones.milestone(id: BabyMilestones.firstWordId))
        XCTAssertEqual(word.caption(name: "Bean", firstWord: "Duck!"), "Bean said “Duck!”!")
        XCTAssertEqual(word.caption(name: "Bean", firstWord: ""), "Bean said “Mama”!")
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
        XCTAssertEqual(state.clean, 70 - BabyState.slowNeedsPerClear)
        XCTAssertEqual(state.rest, 70 - BabyState.slowNeedsPerClear)
    }

    /// Kid-friendly: needs never drop below the floor, however many desks are cleared in a row.
    func testNeedsNeverDropBelowTheFloor() {
        var state = BabyState()
        for _ in 0..<20 { state.applyClear(stars: 1, isFirstClear: false) }
        for need in BabyNeed.allCases {
            XCTAssertEqual(state.value(of: need), BabyState.needsFloor, "\(need)")
        }
    }

    func testClearReportsTheNewStage() {
        var state = BabyState()
        state.growthPoints = BabyStage.infant.threshold - 10
        let reward = state.applyClear(stars: 1, isFirstClear: true) // +10 -> infant
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
        XCTAssertEqual(state.feed(item("food.porridge")), .tooYoung(needs: .roller))
        state.growthPoints = BabyStage.roller.threshold
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

    func testBathIsFreeCleansAndCheersUp() {
        var state = BabyState()
        state.clean = 40
        XCTAssertEqual(state.bathe(), .done(grewTo: nil))
        XCTAssertEqual(state.clean, BabyState.maxNeed)
        XCTAssertEqual(state.joy, 50 + BabyState.bathJoy)
        XCTAssertEqual(state.coins, BabyState.startingCoins, "baths are free")
        XCTAssertEqual(state.growthPoints, BabyState.bathGrowth)
        XCTAssertEqual(state.bathe(), .alreadyFull, "no second bath until a desk is cleared")
        XCTAssertEqual(state.growthPoints, BabyState.bathGrowth)
    }

    func testSleepIsFreeAndRests() {
        var state = BabyState()
        XCTAssertTrue(state.sleep().isDone)
        XCTAssertEqual(state.rest, BabyState.maxNeed)
        XCTAssertEqual(state.coins, BabyState.startingCoins)
        XCTAssertEqual(state.sleep(), .alreadyFull)
        state.applyClear(stars: 1, isFirstClear: false)
        XCTAssertTrue(state.sleep().isDone, "sleepy again after tidying a desk")
    }

    func testWishPrefersFoodThenSleepThenBathThenPlay() {
        var state = BabyState()
        state.tummy = 100
        state.joy = 100
        state.clean = 100
        state.rest = 100
        XCTAssertNil(state.wish)
        state.joy = 30
        XCTAssertEqual(state.wish, .joy)
        state.clean = 30
        XCTAssertEqual(state.wish, .clean)
        state.rest = 30
        XCTAssertEqual(state.wish, .rest)
        state.tummy = 30
        XCTAssertEqual(state.wish, .tummy)
    }

    /// TestFlight switch: everything owned, no age locks, but coins and full needs still apply.
    func testUnlockEverythingOpensAllItems() {
        var state = BabyState()
        state.unlockEverything = true
        XCTAssertTrue(BabyCatalog.items.allSatisfy { state.owns($0) && state.isOldEnough(for: $0) })
        XCTAssertTrue(state.feed(item("food.pasta")).isDone, "explorer food for a newborn")
        XCTAssertTrue(state.play(with: item("toy.crayons")).isDone)
        XCTAssertTrue(state.wear(item("outfit.dino")).isDone)
        XCTAssertEqual(state.buy(item("toy.duck")), .alreadyOwned)
        state.coins = 0
        state.tummy = 50
        XCTAssertEqual(state.feed(item("food.milk")), .notEnoughCoins(missing: 4))
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
        let state = profile.state
        XCTAssertEqual(state.coins, BabyState.startingCoins)
        XCTAssertEqual(state.growthPoints, 0)
        XCTAssertEqual(state.equippedOutfitId, BabyCatalog.defaultOutfitId)
        XCTAssertEqual(state.reachedMilestones.map(\.id), ["hello"], "a new baby gets its first Baby Book page")
        XCTAssertEqual(state.unlockEverything, BetaConfig.unlockAllBabyContent)
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
        let milk = try XCTUnwrap(BabyCatalog.item(id: "food.milk"))
        XCTAssertTrue(profile.update { $0.feed(milk) }.isDone)
        XCTAssertEqual(profile.coins, BabyState.startingCoins - milk.price)
        XCTAssertEqual(profile.hunger, 50 + milk.fill)
        XCTAssertTrue(profile.update { $0.bathe() }.isDone)
        XCTAssertEqual(profile.cleanliness, BabyState.maxNeed)
    }

    func testMilestonesAndFirstWordRoundTrip() throws {
        let context = try makeContext()
        let profile = BabyStore.profile(in: context)
        profile.update { (state: inout BabyState) -> Void in
            state.setAgeForTesting(months: 12)
            state.firstWord = "Duck!"
        }
        try context.save()
        let reloaded = BabyStore.profile(in: context).state
        XCTAssertEqual(reloaded.months, 12)
        XCTAssertEqual(reloaded.firstWord, "Duck!")
        XCTAssertEqual(Set(reloaded.reachedMilestones.map(\.id)),
                       Set(BabyMilestones.all.filter { $0.month <= 12 }.map(\.id)))
        XCTAssertEqual(profile.milestoneIds.count, profile.milestoneDates.count)
    }

    /// Saves made before months / milestones existed catch up on load, without losing anything.
    func testOldSaveCatchesUpOnMilestones() throws {
        let context = try makeContext()
        let old = BabyProfile(name: "Bean")
        old.growthPoints = BabyGrowth.threshold(month: 7)
        old.milestoneIds = []
        old.milestoneDates = []
        context.insert(old)
        try context.save()
        let profile = BabyStore.profile(in: context)
        XCTAssertTrue(profile === old)
        XCTAssertEqual(profile.state.reachedMilestones.count, BabyMilestones.all.filter { $0.month <= 7 }.count)
    }

    func testFirstClearIsToldApartFromAReplay() throws {
        let context = try makeContext()
        XCTAssertFalse(ProgressStore.isCompleted(levelId: 1, in: context))
        ProgressStore.recordClear(levelId: 1, moves: 3, stars: 3, seconds: 10, score: 300, in: context)
        XCTAssertTrue(ProgressStore.isCompleted(levelId: 1, in: context))
        XCTAssertFalse(ProgressStore.isCompleted(levelId: 2, in: context))
    }
}
