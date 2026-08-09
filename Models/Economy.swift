import Foundation

/// Every tunable number in the coin economy.
///
/// Spec 07 makes this a hard requirement rather than a style preference:
/// grepping for a price literal must find exactly one occurrence. Economy
/// tuning running long is a named schedule risk, and scattered constants are
/// what makes it long.
///
/// All values below are provisional. The minutes-to-coins curve and recipe
/// pacing are both open questions in spec 07.
enum Economy {
    static let coinsPerFocusMinute = 1

    /// Awarded on `.completed` only. A burned session earns nothing — that is
    /// the entire weight behind the soft-commitment mechanic (spec 03).
    static func coins(forCompletedMinutes minutes: Int) -> Int {
        max(0, minutes) * coinsPerFocusMinute
    }

    static func price(for id: RecipeID) -> Int {
        switch id {
        case .chocolateChipCookie: 0
        case .croissant: 60
        case .bread: 150
        case .chocolateDonut: 300
        case .fruitTart: 500
        case .cake: 800
        }
    }
}
