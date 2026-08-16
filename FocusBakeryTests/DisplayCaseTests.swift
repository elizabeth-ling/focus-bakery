import Foundation
import Testing
@testable import FocusBakery

/// Spec 08's collection: what the case holds, how it counts, and the sheet that
/// reports it. The rollover rules it shares with spec 02 are covered by
/// `BakeryStoreTests` and `TimeZoneRolloverTests`; this is the case itself.
@MainActor
@Suite("Display case")
struct DisplayCaseTests {
    private let today = DayKey(year: 2026, month: 8, day: 15)

    @Test("Repeated bakes accumulate as quantities in first-baked order")
    func repeatedBakesBecomeQuantities() {
        var display = DisplayCaseDay(date: today)
        for treat in [RecipeID.croissant, .chocolateChipCookie, .croissant, .croissant] {
            display.add(treat)
        }

        #expect(display.tallies == [
            TreatTally(recipeID: .croissant, count: 3),
            TreatTally(recipeID: .chocolateChipCookie, count: 1),
        ])
        // Distinct entries, not distinct treats: the tally is a display of the
        // record, never a replacement for it.
        #expect(display.totalCount == 4)
    }

    @Test("The tally the room draws is the tally the sheet lists")
    func theRoomAndTheSheetAgree() {
        var display = DisplayCaseDay(date: today)
        for treat in [RecipeID.cake, .cake, .fruitTart] { display.add(treat) }

        #expect(TreatTally.tallied(display.treats) == display.tallies)
    }

    @Test("An empty case is empty, and says so without saying anything was lost")
    func anEmptyCaseIsAFreshMorning() {
        let display = DisplayCaseDay(date: today)
        #expect(display.isEmpty)
        #expect(display.totalCount == 0)
        #expect(display.tallies.isEmpty)
    }

    @Test("A day with more bakes than the shelf can show still counts them all")
    func theRecordOutlivesTheShelf() {
        var display = DisplayCaseDay(date: today)
        let treats = (0..<40).map { RecipeID.allCases[$0 % RecipeID.allCases.count] }
        for treat in treats { display.add(treat) }

        #expect(display.totalCount == 40)
        #expect(display.tallies.count == RecipeID.allCases.count)
        #expect(display.tallies.reduce(0) { $0 + $1.count } == 40)
    }

    @Test("The case tap region clears the minimum hit size on every room")
    func theCaseIsBigEnoughToTap() {
        let sizes = [
            CGSize(width: 320, height: 568),
            CGSize(width: 393, height: 852),
            CGSize(width: 440, height: 956),
        ]
        for size in sizes {
            let layout = RoomLayout(fitting: size)
            let region = RoomPlan(fitting: layout).caseRegion(in: layout)
            // Spec 13's 44pt floor, which a single 32pt tile at ×2 would miss.
            #expect(region.width >= 44, "\(size)")
            #expect(region.height >= 44, "\(size)")
        }
    }
}
