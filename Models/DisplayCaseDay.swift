import Foundation

struct TreatTally: Identifiable, Hashable, Sendable {
    let recipeID: RecipeID
    let count: Int

    var id: RecipeID { recipeID }
}

/// Today's output. Fills as you bake and rolls over each morning — this is not
/// data loss, and spec 08 asks that it never be framed to the user as such.
struct DisplayCaseDay: Codable, Hashable, Sendable {
    var date: DayKey
    /// One entry per completed bake, in completion order. Quantities are
    /// derived rather than stored, so order and count can never disagree.
    private(set) var treats: [RecipeID]

    init(date: DayKey, treats: [RecipeID] = []) {
        self.date = date
        self.treats = treats
    }

    var isEmpty: Bool { treats.isEmpty }

    /// The true tally, which spec 08 requires the sheet to show even when the
    /// case has more bakes than it has visible slots.
    var totalCount: Int { treats.count }

    mutating func add(_ recipeID: RecipeID) {
        treats.append(recipeID)
    }

    /// Distinct recipes in first-baked order, with how many of each.
    var tallies: [TreatTally] {
        var order: [RecipeID] = []
        var counts: [RecipeID: Int] = [:]
        for treat in treats {
            if counts[treat] == nil { order.append(treat) }
            counts[treat, default: 0] += 1
        }
        return order.map { TreatTally(recipeID: $0, count: counts[$0] ?? 0) }
    }
}
