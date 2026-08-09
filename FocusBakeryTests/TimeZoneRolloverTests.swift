import Foundation
import Testing
@testable import FocusBakery

@MainActor
@Suite("Timezone changes and rollover")
struct TimeZoneRolloverTests {
    /// The instant is identical throughout; only the zone moves. Spec 08 wants
    /// exactly one reset across such a boundary — not zero, and not two.
    @Test("Flying east rolls the day over exactly once")
    func flyingEastResetsOnce() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 20, 0, in: .newYork), timeZone: .newYork)
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 30)
        clock.advance(hours: 0.5)
        store.finishActiveSession(as: .completed)
        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 14))

        // Landing in Tokyo, thirteen hours ahead, where it is already the 15th.
        clock.timeZone = .tokyo
        #expect(store.refreshForCurrentDay()?.date == DayKey(year: 2026, month: 8, day: 14))
        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.today.displayCase.isEmpty)

        // Foregrounding again in the same zone must not roll it a second time.
        #expect(store.refreshForCurrentDay() == nil)
        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
    }

    @Test("Flying west does not clear a case the user is still filling")
    func flyingWestKeepsTheCase() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 15, 9, 30, in: .tokyo), timeZone: .tokyo)
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 30)
        clock.advance(hours: 0.5)
        store.finishActiveSession(as: .completed)
        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))

        // The same moment in New York is still the 14th.
        clock.timeZone = .newYork
        #expect(store.refreshForCurrentDay() == nil)
        #expect(store.today.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.today.displayCase.totalCount == 1)

        // And the case survives until the local day genuinely passes the 15th.
        clock.advance(hours: 24)
        #expect(store.refreshForCurrentDay() == nil)
        #expect(store.today.displayCase.totalCount == 1)

        clock.advance(hours: 24)
        #expect(store.refreshForCurrentDay()?.date == DayKey(year: 2026, month: 8, day: 15))
        #expect(store.today.displayCase.isEmpty)
    }

    @Test("Remaining time on an in-flight bake is unchanged by a timezone move")
    func timeZoneMoveDoesNotChangeRemainingTime() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9), timeZone: .newYork)
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        let started = store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 50)
        let remainingBefore = started?.endDate.timeIntervalSince(clock.now)

        clock.timeZone = .tokyo
        store.refreshForCurrentDay()

        let remainingAfter = store.session.active?.endDate.timeIntervalSince(clock.now)
        #expect(remainingBefore == remainingAfter)
        #expect(store.session.active?.id == started?.id)
    }
}
