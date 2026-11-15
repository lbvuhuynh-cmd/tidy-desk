import XCTest
import SwiftData
@testable import TidyDesk

final class GoodDeedTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ d: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
    }

    func testDefaultDeeds() {
        XCTAssertEqual(GoodDeeds.all.map(\.points), [10, 15, 20, 10])
        XCTAssertEqual(Set(GoodDeeds.all.map(\.category)), Set(GoodDeed.Category.allCases))
        XCTAssertEqual(Set(GoodDeeds.all.map(\.id)).count, GoodDeeds.all.count, "ids are unique")
        for deed in GoodDeeds.all {
            XCTAssertFalse(deed.emoji.isEmpty, deed.id)
            XCTAssertGreaterThanOrEqual(deed.dailyLimit, 1, deed.id)
            XCTAssertEqual(deed.coins, deed.points)
            XCTAssertEqual(GoodDeeds.deed(id: deed.id), deed)
        }
        XCTAssertEqual(GoodDeeds.kindness.dailyLimit, 2)
        XCTAssertEqual(GoodDeeds.chores.dailyLimit, 1)
    }

    func testLoggingPaysCoinsGrowthAndJoy() {
        var state = BabyState()
        state.joy = 40
        let result = state.logGoodDeed(GoodDeeds.chores, now: day(14), calendar: calendar)
        guard case .done(let reward) = result else { return XCTFail("expected done, got \(result)") }
        XCTAssertEqual(reward.coins, 15)
        XCTAssertEqual(reward.growth, 7)
        XCTAssertEqual(state.coins, BabyState.startingCoins + 15)
        XCTAssertEqual(state.growthPoints, 7)
        XCTAssertEqual(state.joy, 50)
        XCTAssertEqual(state.goodDeeds, [GoodDeedEntry(deedId: GoodDeeds.chores.id, date: day(14))])
    }

    func testDailyLimitResetsTheNextDay() {
        var state = BabyState()
        XCTAssertTrue(state.logGoodDeed(GoodDeeds.exercise, now: day(14, hour: 8), calendar: calendar).isDone)
        XCTAssertEqual(state.logGoodDeed(GoodDeeds.exercise, now: day(14, hour: 18), calendar: calendar), .dailyLimitReached)
        XCTAssertFalse(state.canDo(GoodDeeds.exercise, now: day(14, hour: 20), calendar: calendar))
        // Other deeds are counted separately.
        XCTAssertTrue(state.canDo(GoodDeeds.school, now: day(14), calendar: calendar))
        // Tomorrow it's open again.
        XCTAssertTrue(state.logGoodDeed(GoodDeeds.exercise, now: day(15, hour: 8), calendar: calendar).isDone)
        XCTAssertEqual(state.coins, BabyState.startingCoins + 20, "the refused one paid nothing")
    }

    func testKindnessTwiceADay() {
        var state = BabyState()
        XCTAssertTrue(state.logGoodDeed(GoodDeeds.kindness, now: day(14, hour: 9), calendar: calendar).isDone)
        XCTAssertEqual(state.timesDone(GoodDeeds.kindness, on: day(14), calendar: calendar), 1)
        XCTAssertTrue(state.logGoodDeed(GoodDeeds.kindness, now: day(14, hour: 15), calendar: calendar).isDone)
        XCTAssertEqual(state.logGoodDeed(GoodDeeds.kindness, now: day(14, hour: 19), calendar: calendar), .dailyLimitReached)
    }

    func testTestFlightLiftsTheDailyLimit() {
        var state = BabyState()
        state.unlockEverything = true
        for hour in 8...11 {
            XCTAssertTrue(state.logGoodDeed(GoodDeeds.school, now: day(14, hour: hour), calendar: calendar).isDone)
        }
        XCTAssertEqual(state.coins, BabyState.startingCoins + 80)
    }

    func testUnknownDeedIsRejected() {
        var state = BabyState()
        let fake = GoodDeed(id: "deed.fake", title: "Fake", emoji: "❓", detail: "", points: 999,
                            category: .chores, dailyLimit: 9)
        XCTAssertEqual(state.logGoodDeed(fake), .invalid)
        XCTAssertEqual(state.coins, BabyState.startingCoins)
    }

    func testThisWeekAndHistoryTrimming() {
        var state = BabyState()
        state.unlockEverything = true
        _ = state.logGoodDeed(GoodDeeds.exercise, now: day(1), calendar: calendar)    // two weeks ago
        _ = state.logGoodDeed(GoodDeeds.chores, now: day(9), calendar: calendar)      // 6 days ago: in the week
        _ = state.logGoodDeed(GoodDeeds.school, now: day(15), calendar: calendar)
        XCTAssertEqual(state.goodDeedsThisWeek(now: day(15, hour: 12), calendar: calendar).map(\.deedId),
                       [GoodDeeds.chores.id, GoodDeeds.school.id])
        // Two months later the old entries are dropped when a new one is added.
        let later = calendar.date(byAdding: .day, value: GoodDeeds.historyDays + 5, to: day(15))!
        _ = state.logGoodDeed(GoodDeeds.kindness, now: later, calendar: calendar)
        XCTAssertEqual(state.goodDeeds.map(\.deedId), [GoodDeeds.kindness.id])
    }

    func testGoodDeedCanReachAMilestone() {
        var state = BabyState()
        state.growthPoints = BabyGrowth.threshold(month: 2) - 1   // one point before "First Smile"
        guard case .done(let reward) = state.logGoodDeed(GoodDeeds.exercise) else { return XCTFail() }
        XCTAssertTrue(reward.newMilestones.contains { $0.id == "first_smile" })
    }

    func testParentGateQuestion() {
        let question = ParentGateQuestion(a: 7, b: 8)
        XCTAssertTrue(question.isAnswered(by: "56"))
        XCTAssertTrue(question.isAnswered(by: " 56 "))
        XCTAssertFalse(question.isAnswered(by: "54"))
        XCTAssertFalse(question.isAnswered(by: ""))
        for _ in 0..<50 {
            XCTAssertGreaterThanOrEqual(ParentGateQuestion.random().answer, 18, "always a two-digit answer")
        }
    }
}

@MainActor
final class GoodDeedStoreTests: XCTestCase {
    func testGoodDeedsAreSavedOnTheProfile() throws {
        let container = try ModelContainer(for: LevelProgress.self, BabyProfile.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let result = BabyStore.logGoodDeed(GoodDeeds.school, in: context)
        XCTAssertTrue(result.isDone)
        let profile = BabyStore.profile(in: context)
        XCTAssertEqual(profile.goodDeedIds, [GoodDeeds.school.id])
        XCTAssertEqual(profile.goodDeedDates.count, 1)
        XCTAssertEqual(profile.coins, BabyState.startingCoins + GoodDeeds.school.coins)
        XCTAssertEqual(profile.state.goodDeeds.map(\.deedId), [GoodDeeds.school.id], "round-trips through the state")
    }
}
