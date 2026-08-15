import Foundation
import Testing
@testable import FocusBakery

@MainActor
@Suite("Persistence and the daily reset")
struct BakeryStoreTests {
    @Test("Killing and relaunching preserves coins, unlocks, the case, and the in-flight bake")
    func coldRelaunchPreservesState() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))

        let before = BakeryStore(directory: directory, clock: clock.wallClock)
        before.startSession(recipeID: .chocolateChipCookie, durationMinutes: 90)
        clock.advance(hours: 1.5)
        before.finishActiveSession(as: .completed)
        #expect(before.purchase(.croissant) == .bought)
        before.recordIntention("ship the data layer")
        let inFlight = before.startSession(recipeID: .croissant, durationMinutes: 25)

        let after = BakeryStore(directory: directory, clock: clock.wallClock)

        #expect(after.progress.wallet.coinBalance == 30)
        #expect(after.isUnlocked(.croissant))
        #expect(after.today.displayCase.treats == [.chocolateChipCookie])
        #expect(after.today.focusMinutes == 90)
        #expect(after.today.ritual.intentionText == "ship the data layer")
        #expect(after.session.active?.id == inFlight?.id)
        #expect(after.session.active?.endDate == inFlight?.endDate)
    }

    @Test("A daily reset clears the display case and leaves the recipe book untouched")
    func resetClearsCaseButNotProgress() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 90)
        clock.advance(hours: 1.5)
        store.finishActiveSession(as: .completed)
        #expect(store.purchase(.croissant) == .bought)

        clock.advance(hours: 24)
        let retired = store.refreshForCurrentDay()

        #expect(retired?.date == DayKey(year: 2026, month: 8, day: 14))
        #expect(retired?.treatCount == 1)
        #expect(retired?.focusMinutes == 90)
        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.today.displayCase.isEmpty)
        #expect(store.today.focusMinutes == 0)
        #expect(store.isUnlocked(.croissant))
        #expect(store.progress.wallet.coinBalance == 30)
    }

    @Test("A reset never clobbers an in-flight bake")
    func resetPreservesInFlightSession() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 23, 30))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        let started = store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 60)
        clock.advance(hours: 1)
        store.refreshForCurrentDay()

        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.session.active?.id == started?.id)
        #expect(store.session.active?.endDate == started?.endDate)
        #expect(store.session.active?.outcome == .inProgress)
    }

    @Test("A bake crossing midnight files its treat under the day it finished in")
    func treatLandsInTheDayItCompletes() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 23, 30))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 60)
        clock.advance(hours: 1)
        store.finishActiveSession(as: .completed)

        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.today.displayCase.treats == [.chocolateChipCookie])
        #expect(store.today.focusMinutes == 60)
    }

    @Test("Repeated foregrounding within one day never resets the case")
    func foregroundingWithinADayDoesNotReset() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 30)
        clock.advance(hours: 0.5)
        store.finishActiveSession(as: .completed)

        for _ in 0..<5 {
            clock.advance(hours: 1)
            #expect(store.refreshForCurrentDay() == nil)
        }
        #expect(store.today.displayCase.totalCount == 1)
    }

    @Test("At most one session is in progress at a time")
    func onlyOneSessionInFlight() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        let first = store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
        let second = store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)

        #expect(first != nil)
        #expect(second == nil)
        #expect(store.session.active?.id == first?.id)
        #expect(store.session.active?.durationMinutes == 25)
    }

    @Test("Resolving a session twice awards once")
    func resolvingTwiceAwardsOnce() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 30)
        clock.advance(hours: 0.5)

        #expect(store.finishActiveSession(as: .completed) != nil)
        #expect(store.finishActiveSession(as: .completed) == nil)

        #expect(store.progress.wallet.coinBalance == 30)
        #expect(store.today.displayCase.totalCount == 1)
    }

    @Test("A burned session awards no coins and no treat")
    func burnedSessionAwardsNothing() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)
        clock.advance(hours: 0.2)
        let burned = store.finishActiveSession(as: .burned)

        #expect(burned?.outcome == .burned)
        #expect(store.session.active == nil)
        #expect(store.progress.wallet.coinBalance == 0)
        #expect(store.today.displayCase.isEmpty)
        #expect(store.today.focusMinutes == 0)
    }

    @Test("An already-resolved session is not restored into the live slot")
    func resolvedSessionIsNotRestored() throws {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))

        let stale = BakeSession(
            recipeID: .chocolateChipCookie,
            startDate: clock.now,
            durationMinutes: 25,
            outcome: .completed
        )
        let data = try JSONEncoder().encode(SessionState(active: stale))
        try data.write(to: directory.appending(path: "session.json"))

        let store = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(store.session.active == nil)
    }

    @Test("A locked recipe cannot be baked")
    func lockedRecipeCannotStart() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        #expect(store.startSession(recipeID: .cake, durationMinutes: 25) == nil)
        #expect(store.session.active == nil)
    }
}
