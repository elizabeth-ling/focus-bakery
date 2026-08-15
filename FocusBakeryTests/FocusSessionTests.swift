import Foundation
import Testing
@testable import FocusBakery

/// Spec 03's acceptance criteria, driven through the store the app actually
/// talks to — start, leave, return, relaunch.
@MainActor
@Suite("Focus session timer")
struct FocusSessionTests {
    @Test("A bake that ended while the app was suspended resolves once on return")
    func suspendedBakeResolvesOnReturn() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
        // Left with less than the grace left to run, so the absence is inside
        // policy and the bake survives it.
        clock.advance(minutes: 25)
        clock.advance(seconds: -(BurnPolicy.backgroundGrace - 5))
        store.noteLeftForeground()
        clock.advance(hours: 2)

        let resolved = store.resolveInFlightSession()

        #expect(resolved?.outcome == .completed)
        #expect(store.pendingOutcome?.id == resolved?.id)
        #expect(store.progress.wallet.coinBalance == Economy.coins(forCompletedMinutes: 25))
        #expect(store.today.displayCase.treats == [.chocolateChipCookie])
        #expect(store.today.focusMinutes == 25)

        // The foreground pass runs on every return, and the display tick runs
        // every second: neither may award a second time.
        #expect(store.resolveInFlightSession() == nil)
        #expect(store.progress.wallet.coinBalance == Economy.coins(forCompletedMinutes: 25))
        #expect(store.today.displayCase.totalCount == 1)
    }

    @Test("The live tick completes a bake the user sat through, exactly once")
    func liveTickCompletesOnce() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
        for _ in 0..<5 {
            clock.advance(minutes: 1)
            #expect(store.resolveInFlightSession() == nil)
        }
        clock.advance(minutes: 20)

        #expect(store.resolveInFlightSession()?.outcome == .completed)
        #expect(store.resolveInFlightSession() == nil)
        #expect(store.progress.wallet.coinBalance == Economy.coins(forCompletedMinutes: 25))
        #expect(store.today.displayCase.totalCount == 1)
    }

    @Test("Backgrounding for longer than the bake burns it")
    func backgroundingPastTheGraceBurns() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
        clock.advance(minutes: 1)
        store.noteLeftForeground()
        clock.advance(hours: 1)

        #expect(store.resolveInFlightSession()?.outcome == .burned)
        #expect(store.pendingOutcome?.outcome == .burned)
        #expect(store.progress.wallet.coinBalance == 0)
        #expect(store.today.displayCase.isEmpty)
        #expect(store.today.focusMinutes == 0)
        #expect(store.session.active == nil)
    }

    @Test("Force-quitting while away burns the bake on the next cold launch")
    func killedWhileAwayBurnsOnRelaunch() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))

        let before = BakeryStore(directory: directory, clock: clock.wallClock)
        before.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)
        clock.advance(minutes: 2)
        before.noteLeftForeground()

        clock.advance(hours: 3)
        let after = BakeryStore(directory: directory, clock: clock.wallClock)

        #expect(after.resolveInFlightSession()?.outcome == .burned)
        #expect(after.progress.wallet.coinBalance == 0)
        #expect(after.today.displayCase.isEmpty)

        // Relaunching again must find nothing left to resolve.
        let third = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(third.resolveInFlightSession() == nil)
        #expect(third.progress.wallet.coinBalance == 0)
    }

    @Test("Force-quitting inside policy still completes and awards once")
    func killedWhileAwayCompletesOnRelaunch() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))

        let before = BakeryStore(directory: directory, clock: clock.wallClock)
        before.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
        clock.advance(minutes: 25)
        clock.advance(seconds: -(BurnPolicy.backgroundGrace - 5))
        before.noteLeftForeground()

        clock.advance(hours: 8)
        let after = BakeryStore(directory: directory, clock: clock.wallClock)

        #expect(after.resolveInFlightSession()?.outcome == .completed)
        #expect(after.progress.wallet.coinBalance == Economy.coins(forCompletedMinutes: 25))

        let third = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(third.resolveInFlightSession() == nil)
        #expect(third.progress.wallet.coinBalance == Economy.coins(forCompletedMinutes: 25))
        #expect(third.today.displayCase.totalCount == 1)
    }

    @Test("A bake started before midnight survives the reset and lands in the new day")
    func bakeSurvivesMidnight() {
        let clock = TestClock(instant(2026, 8, 14, 23))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 1)
        clock.advance(minutes: 1)
        store.resolveInFlightSession()
        #expect(store.today.displayCase.totalCount == 1)

        let overnight = store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 60)
        clock.advance(minutes: 59)
        store.refreshForCurrentDay()

        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.today.displayCase.isEmpty)
        #expect(store.session.active?.id == overnight?.id)
        #expect(store.resolution == .baking(remaining: 60))

        clock.advance(minutes: 1)
        #expect(store.resolveInFlightSession()?.outcome == .completed)
        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.today.displayCase.treats == [.chocolateChipCookie])
        #expect(store.today.focusMinutes == 60)
    }

    @Test("A timezone change that rolls the day leaves the remaining time untouched")
    func timezoneChangeDoesNotMoveTheEndDate() {
        let clock = TestClock(instant(2026, 8, 14, 20))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)
        clock.advance(minutes: 20)
        let beforeFlight = store.resolution

        // Landing in Tokyo, where it is already tomorrow: the day key moves, the
        // absolute end date does not.
        clock.timeZone = .tokyo
        store.refreshForCurrentDay()

        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.resolution == beforeFlight)
        #expect(store.resolution == .baking(remaining: 1800))
        #expect(store.resolveInFlightSession() == nil)
    }

    @Test("A deliberate cancel burns the bake and announces nothing")
    func deliberateCancelBurnsQuietly() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)
        clock.advance(minutes: 10)

        #expect(store.finishActiveSession(as: .burned)?.outcome == .burned)
        // The user just confirmed it; only the lazy path owes them news.
        #expect(store.pendingOutcome == nil)
        #expect(store.progress.wallet.coinBalance == 0)
        #expect(store.resolution == .idle)
    }

    @Test("The grace runs from the first departure and is not extended")
    func graceIsNotExtendedBySecondBackgrounding() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)
        store.noteLeftForeground()
        clock.advance(seconds: BurnPolicy.backgroundGrace - 5)
        store.noteLeftForeground()
        clock.advance(seconds: 10)

        #expect(store.resolveInFlightSession()?.outcome == .burned)
    }

    @Test("The grace is spent per departure, never banked")
    func graceResetsAfterASurvivedAbsence() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)
        store.noteLeftForeground()
        clock.advance(seconds: BurnPolicy.backgroundGrace - 5)
        #expect(store.noteReturnedToForeground() == nil)
        #expect(store.session.leftForegroundAt == nil)

        store.noteLeftForeground()
        clock.advance(seconds: BurnPolicy.backgroundGrace - 5)

        #expect(store.noteReturnedToForeground() == nil)
        #expect(store.session.active != nil)
    }

    @Test("A display tick after backgrounding does not spend the departure")
    func displayTickDoesNotSpendTheDeparture() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)
        store.noteLeftForeground()
        let departure = store.session.leftForegroundAt

        // The `.task` loop keeps ticking for a moment after the app is
        // backgrounded. Clearing the mark there would make the burn unreachable.
        for _ in 0..<3 {
            clock.advance(seconds: 1)
            #expect(store.resolveInFlightSession() == nil)
        }
        #expect(store.session.leftForegroundAt == departure)

        clock.advance(seconds: BurnPolicy.backgroundGrace)
        #expect(store.noteReturnedToForeground()?.outcome == .burned)
    }

    @Test("Leaving with no bake in flight records nothing")
    func leavingWithoutABakeRecordsNothing() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.noteLeftForeground()

        #expect(store.session.leftForegroundAt == nil)
        #expect(store.resolveInFlightSession() == nil)
    }

    @Test("An outcome is announced once and then acknowledged")
    func outcomeIsAcknowledged() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
        clock.advance(minutes: 30)
        store.resolveInFlightSession()

        #expect(store.pendingOutcome != nil)
        store.acknowledgeOutcome()
        #expect(store.pendingOutcome == nil)
    }

    @Test("A departure recorded against an abandoned bake does not outlive it")
    func departureIsClearedWithTheSession() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))

        let before = BakeryStore(directory: directory, clock: clock.wallClock)
        before.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
        before.noteLeftForeground()
        clock.advance(hours: 1)
        before.resolveInFlightSession()

        #expect(before.session.leftForegroundAt == nil)

        // A stale departure surviving on disk would burn the next bake instantly.
        let after = BakeryStore(directory: directory, clock: clock.wallClock)
        after.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
        clock.advance(minutes: 1)

        #expect(after.resolveInFlightSession() == nil)
        #expect(after.resolution == .baking(remaining: 1440))
    }
}
