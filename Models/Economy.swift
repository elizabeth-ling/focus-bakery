import Foundation

/// Every tunable number in the coin economy.
///
/// Spec 07 makes this a hard requirement rather than a style preference:
/// grepping for a price literal must find exactly one occurrence. Economy
/// tuning running long is a named schedule risk, and scattered constants are
/// what makes it long. Nothing outside this file may name an earn rate or a
/// price — callers ask `coins(forCompletedMinutes:)` and `price(for:)`, and so
/// do the tests, apart from the one suite that pins this curve itself.
enum Economy {
    /// Coins per minute, banded by how deep into the session the minute falls.
    ///
    /// Weighted rather than flat, which is the resolution of spec 07's open
    /// question. At a single flat rate five five-minute bakes pay exactly what
    /// one twenty-five-minute bake does, and a product whose whole premise is
    /// depth should not be indifferent between those.
    ///
    /// Each band's rate applies only to the minutes falling inside it, so the
    /// curve is continuous. A banded *total* would put a cliff at each
    /// threshold and reward stopping just past one.
    private static let earnBands: [(throughMinute: Int, coinsPerMinute: Int)] = [
        (15, 1),
        (45, 2),
        (Int.max, 3),
    ]

    /// Awarded on `.completed` only. A burned session earns nothing — that is
    /// the entire weight behind the soft-commitment mechanic (spec 03).
    static func coins(forCompletedMinutes minutes: Int) -> Int {
        var remaining = max(0, minutes)
        var earned = 0
        var bandStart = 0

        for band in earnBands where remaining > 0 {
            let minutesInBand = min(remaining, band.throughMinute - bandStart)
            earned += minutesInBand * band.coinsPerMinute
            remaining -= minutesInBand
            bandStart = band.throughMinute
        }
        return earned
    }

    /// Paced so the second recipe lands within two or three sessions — the
    /// first unlock has to arrive while the user is still deciding whether the
    /// loop is worth keeping — and stretches out from there to a cake that is a
    /// long-haul goal rather than a purchase.
    static func price(for id: RecipeID) -> Int {
        switch id {
        case .chocolateChipCookie: 0
        case .croissant: 70
        case .bread: 210
        case .chocolateDonut: 455
        case .fruitTart: 840
        case .cake: 1400
        }
    }
}
