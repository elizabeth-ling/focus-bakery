import Foundation

/// The day's open and close ritual (spec 09). Both prompts are skippable, so
/// both texts stay optional — a skipped prompt is a nil answer on a ritual that
/// still opened, not an absent ritual.
struct DailyRitual: Codable, Hashable, Sendable {
    var date: DayKey
    var intentionText: String?
    var reflectionText: String?
    var openedAt: Date?
    var closedAt: Date?

    init(date: DayKey) {
        self.date = date
    }

    var hasAnsweredIntention: Bool {
        intentionText?.isEmpty == false
    }
}
