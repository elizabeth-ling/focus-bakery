import Foundation

struct TreatTally: Identifiable, Hashable, Sendable {
    let recipeID: RecipeID
    let count: Int

    var id: RecipeID { recipeID }

    /// Distinct recipes in first-baked order, with how many of each.
    ///
    /// Shared by the case in the room and the sheet that lists it, so a
    /// quantity can never read one way in-scene and another in the list.
    static func tallied(_ treats: [RecipeID]) -> [TreatTally] {
        var order: [RecipeID] = []
        var counts: [RecipeID: Int] = [:]
        for treat in treats {
            if counts[treat] == nil { order.append(treat) }
            counts[treat, default: 0] += 1
        }
        return order.map { TreatTally(recipeID: $0, count: counts[$0] ?? 0) }
    }
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

    /// Treats decode leniently so an id this build no longer knows about costs
    /// one entry rather than the whole day.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(DayKey.self, forKey: .date)
        let raw = try container.decodeIfPresent([String].self, forKey: .treats) ?? []
        treats = raw.compactMap(RecipeID.init(rawValue:))
    }

    var isEmpty: Bool { treats.isEmpty }

    /// The true tally, which spec 08 requires the sheet to show even when the
    /// case has more bakes than it has visible slots.
    var totalCount: Int { treats.count }

    mutating func add(_ recipeID: RecipeID) {
        treats.append(recipeID)
    }

    /// Distinct recipes in first-baked order, with how many of each.
    var tallies: [TreatTally] { TreatTally.tallied(treats) }
}
