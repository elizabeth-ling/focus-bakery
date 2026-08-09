import Foundation

/// Streak *state* only. What qualifies a day is deliberately not expressed
/// here: spec 09 requires the condition to be a single configurable definition
/// that can be locked later without a refactor, and forbids streak or economy
/// code from embedding an assumption about it.
struct StreakState: Codable, Hashable, Sendable {
    /// Count and replenishment are open questions in spec 09.
    static let startingGraceDays = 1

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastQualifyingDate: DayKey?
    var graceDaysAvailable: Int = startingGraceDays
    var graceDayUsedOn: DayKey?
}
