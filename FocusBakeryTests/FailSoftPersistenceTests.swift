import Foundation
import Testing
@testable import FocusBakery

@MainActor
@Suite("Fail-soft persistence")
struct FailSoftPersistenceTests {
    @Test("Unreadable display-case data never takes the recipe book with it")
    func corruptTodayKeepsProgress() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))

        let before = BakeryStore(directory: directory, clock: clock.wallClock)
        before.startSession(recipeID: .chocolateChipCookie, durationMinutes: 90)
        clock.advance(hours: 1.5)
        before.finishActiveSession(as: .completed)
        #expect(before.purchase(.croissant) == .bought)

        writeGarbage(to: directory.appending(path: "today.json"))

        let after = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(after.isUnlocked(.croissant))
        #expect(after.progress.wallet.coinBalance
                == Economy.coins(forCompletedMinutes: 90) - Economy.price(for: .croissant))
        #expect(after.today.displayCase.isEmpty)
        #expect(after.today.date == DayKey(year: 2026, month: 8, day: 14))
    }

    @Test("An unreadable progress file falls back to a clean first run")
    func corruptProgressFailsSoft() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))

        let before = BakeryStore(directory: directory, clock: clock.wallClock)
        before.startSession(recipeID: .chocolateChipCookie, durationMinutes: 30)
        clock.advance(hours: 0.5)
        before.finishActiveSession(as: .completed)

        writeGarbage(to: directory.appending(path: "progress.json"))

        let after = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(after.progress.wallet.coinBalance == 0)
        #expect(after.progress.unlockedRecipeIDs == [RecipeCatalog.starter])
        #expect(after.today.displayCase.totalCount == 1)
    }

    @Test("An unreadable session file loses the bake but nothing else")
    func corruptSessionFailsSoft() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))

        let before = BakeryStore(directory: directory, clock: clock.wallClock)
        before.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)

        writeGarbage(to: directory.appending(path: "session.json"))

        let after = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(after.session.active == nil)
        #expect(after.progress.unlockedRecipeIDs == [RecipeCatalog.starter])
    }

    @Test("A fresh install starts clean with only the starter unlocked")
    func freshInstallIsClean() {
        let store = BakeryStore(
            directory: makeTemporaryDirectory(),
            clock: TestClock(instant(2026, 8, 14, 9)).wallClock
        )

        #expect(store.progress.wallet.coinBalance == 0)
        #expect(store.progress.unlockedRecipeIDs == [.chocolateChipCookie])
        #expect(store.progress.streak.currentStreak == 0)
        #expect(store.session.active == nil)
        #expect(store.today.displayCase.isEmpty)
    }

    @Test("Progress decoding tolerates missing fields and unknown recipe ids")
    func progressDecodingIsLenient() throws {
        let json = """
        {"wallet":{"coinBalance":42},"unlockedRecipeIDs":["croissant","pretzelOfTheAncients"]}
        """
        let decoded = try JSONDecoder().decode(ProgressState.self, from: Data(json.utf8))

        #expect(decoded.wallet.coinBalance == 42)
        #expect(decoded.unlockedRecipeIDs == [.chocolateChipCookie, .croissant])
        #expect(decoded.streak.currentStreak == 0)
    }

    @Test("The display case drops treats this build no longer knows about")
    func displayCaseDecodingIsLenient() throws {
        let json = """
        {"date":{"year":2026,"month":8,"day":14},"treats":["cookie","chocolateChipCookie","cake"]}
        """
        let decoded = try JSONDecoder().decode(DisplayCaseDay.self, from: Data(json.utf8))

        #expect(decoded.treats == [.chocolateChipCookie, .cake])
        #expect(decoded.date == DayKey(year: 2026, month: 8, day: 14))
    }

    @Test("Streak state survives a round trip so a relaunch keeps it")
    func streakRoundTrips() throws {
        var progress = ProgressState()
        progress.streak = StreakState(
            currentStreak: 7,
            longestStreak: 12,
            lastQualifyingDate: DayKey(year: 2026, month: 8, day: 13),
            graceDaysAvailable: 0,
            graceDayUsedOn: DayKey(year: 2026, month: 8, day: 10)
        )

        let decoded = try JSONDecoder().decode(
            ProgressState.self,
            from: JSONEncoder().encode(progress)
        )
        #expect(decoded.streak == progress.streak)
    }
}
