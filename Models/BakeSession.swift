import Foundation

struct BakeSession: Identifiable, Codable, Hashable, Sendable {
    enum Outcome: String, Codable, Sendable {
        case inProgress
        case completed
        case burned
    }

    let id: UUID
    let recipeID: RecipeID
    let startDate: Date
    /// The *target* end, stored absolutely. Spec 03 makes this the timer's
    /// source of truth: remaining time is `endDate - now`, recomputed from
    /// wall-clock, never a counter that drifts or dies on backgrounding.
    let endDate: Date
    let durationMinutes: Int
    var outcome: Outcome

    init(
        id: UUID = UUID(),
        recipeID: RecipeID,
        startDate: Date,
        durationMinutes: Int,
        outcome: Outcome = .inProgress
    ) {
        self.id = id
        self.recipeID = recipeID
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes) * 60)
        self.outcome = outcome
    }
}
