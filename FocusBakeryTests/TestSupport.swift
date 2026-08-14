import Foundation
@testable import FocusBakery

/// A clock the tests can move forwards, backwards, and sideways into another
/// timezone, so the wall-clock cases in specs 02, 03 and 08 can be driven
/// without sleeping.
final class TestClock: @unchecked Sendable {
    var now: Date
    var timeZone: TimeZone

    init(_ now: Date, timeZone: TimeZone = .newYork) {
        self.now = now
        self.timeZone = timeZone
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    var wallClock: WallClock {
        WallClock(now: { [self] in now }, calendar: { [self] in calendar })
    }

    func advance(hours: Double) {
        now += hours * 3600
    }

    func advance(minutes: Double) {
        now += minutes * 60
    }

    func advance(seconds: Double) {
        now += seconds
    }
}

extension TimeZone {
    static let newYork = TimeZone(identifier: "America/New_York")!
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
}

/// Absolute instant for a local wall-clock reading in a given zone.
func instant(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 12,
    _ minute: Int = 0,
    in timeZone: TimeZone = .newYork
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(
        from: DateComponents(
            timeZone: timeZone,
            year: year, month: month, day: day, hour: hour, minute: minute
        )
    )!
}

/// A directory of its own per test, so stores never see another test's files.
func makeTemporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "FocusBakeryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// A defaults domain of its own per test, so preferences never leak between
/// tests or into the app's own domain.
func makeTemporaryDefaults() -> UserDefaults {
    UserDefaults(suiteName: "FocusBakeryTests-\(UUID().uuidString)")!
}

func writeGarbage(to url: URL) {
    try? Data("{ not json at all".utf8).write(to: url)
}
