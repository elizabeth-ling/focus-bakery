import Foundation

/// A day in the user's local calendar.
///
/// Stored as calendar components rather than as an instant: a persisted `Date`
/// re-derives to a different day once the timezone changes, which is what turns
/// one daily reset into zero or two.
struct DayKey: Hashable, Codable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, in calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 0
        month = components.month ?? 0
        day = components.day ?? 0
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Midday rather than midnight, because some zones skip midnight entirely on
    /// a DST transition and `date(from:)` then resolves to the previous day.
    func middayDate(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    /// Calendar days from `earlier` to `self`; negative if `self` is earlier.
    func daysSince(_ earlier: DayKey, in calendar: Calendar) -> Int? {
        guard let start = earlier.middayDate(in: calendar),
              let end = middayDate(in: calendar) else { return nil }
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}

/// The single source of "what time is it, and in whose calendar".
///
/// Spec 03 asks for an injectable now so wall-clock scenarios are testable
/// without sleeping; the calendar travels with it because every day-boundary
/// question needs both.
struct WallClock: Sendable {
    var now: @Sendable () -> Date
    var calendar: @Sendable () -> Calendar

    /// The calendar is read per call, not captured once. Capturing it at launch
    /// would pin the timezone the app started in, and a change while
    /// backgrounded would never be picked up on foreground.
    static let system = WallClock(now: { Date() }, calendar: { Calendar.current })

    var today: DayKey {
        DayKey(now(), in: calendar())
    }
}
