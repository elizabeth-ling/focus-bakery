import Foundation
import Testing
@testable import FocusBakery

@Suite("Day boundary")
struct DayKeyTests {
    @Test("A day key comes from the local calendar, not UTC")
    func dayKeyUsesLocalCalendar() {
        // 23:30 in New York is already the next day in UTC.
        let lateEvening = instant(2026, 8, 14, 23, 30, in: .newYork)

        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = .newYork
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt

        #expect(DayKey(lateEvening, in: newYork) == DayKey(year: 2026, month: 8, day: 14))
        #expect(DayKey(lateEvening, in: utc) == DayKey(year: 2026, month: 8, day: 15))
    }

    @Test("The same instant is a different day in a different zone")
    func sameInstantDiffersByZone() {
        let moment = instant(2026, 8, 14, 23, 30, in: .newYork)
        let clock = TestClock(moment, timeZone: .newYork)

        #expect(clock.wallClock.today == DayKey(year: 2026, month: 8, day: 14))

        clock.timeZone = .tokyo
        #expect(clock.wallClock.today == DayKey(year: 2026, month: 8, day: 15))
    }

    @Test("Day keys order chronologically across month and year ends")
    func dayKeysOrder() {
        #expect(DayKey(year: 2026, month: 8, day: 14) < DayKey(year: 2026, month: 8, day: 15))
        #expect(DayKey(year: 2026, month: 8, day: 31) < DayKey(year: 2026, month: 9, day: 1))
        #expect(DayKey(year: 2026, month: 12, day: 31) < DayKey(year: 2027, month: 1, day: 1))
    }

    @Test("Consecutive days are one day apart across a DST transition")
    func dstTransitionsAreStillOneDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .newYork

        // 2026-03-08 loses an hour; 2026-11-01 gains one.
        let springForward = DayKey(year: 2026, month: 3, day: 8)
        let dayBeforeSpring = DayKey(year: 2026, month: 3, day: 7)
        let fallBack = DayKey(year: 2026, month: 11, day: 1)
        let dayBeforeFall = DayKey(year: 2026, month: 10, day: 31)

        #expect(springForward.daysSince(dayBeforeSpring, in: calendar) == 1)
        #expect(fallBack.daysSince(dayBeforeFall, in: calendar) == 1)
    }

    @Test("Day distance counts backwards and across a year end")
    func dayDistanceSigned() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .newYork

        let newYearsDay = DayKey(year: 2027, month: 1, day: 1)
        let newYearsEve = DayKey(year: 2026, month: 12, day: 31)

        #expect(newYearsDay.daysSince(newYearsEve, in: calendar) == 1)
        #expect(newYearsEve.daysSince(newYearsDay, in: calendar) == -1)
        #expect(newYearsDay.daysSince(newYearsDay, in: calendar) == 0)
    }

    @Test("A day key survives a round trip through JSON")
    func dayKeyRoundTrips() throws {
        let key = DayKey(year: 2026, month: 8, day: 14)
        let decoded = try JSONDecoder().decode(DayKey.self, from: JSONEncoder().encode(key))
        #expect(decoded == key)
    }
}
