import Foundation
import Testing
@testable import FocusBakery

@Suite("The recipe-book modal")
struct RecipeBookModalTests {
    private let cookieAndCroissant = [
        RecipeCatalog.recipe(for: .chocolateChipCookie),
        RecipeCatalog.recipe(for: .croissant),
    ]

    @Test("Arrows cycle through the unlocked recipes and wrap at both ends")
    func cyclingWraps() {
        let unlocked = cookieAndCroissant
        #expect(RecipeBookModalView.cycled(from: .chocolateChipCookie, by: 1, in: unlocked) == .croissant)
        #expect(RecipeBookModalView.cycled(from: .croissant, by: 1, in: unlocked) == .chocolateChipCookie)
        #expect(RecipeBookModalView.cycled(from: .chocolateChipCookie, by: -1, in: unlocked) == .croissant)
    }

    @Test("Cycling never leaves the unlocked set, whatever it is asked from")
    func cyclingStaysUnlocked() {
        let unlocked = cookieAndCroissant
        let unlockedIDs = Set(unlocked.map(\.id))
        for id in RecipeID.allCases {
            for delta in [-1, 1] {
                #expect(unlockedIDs.contains(RecipeBookModalView.cycled(from: id, by: delta, in: unlocked)))
            }
        }
    }

    @Test("With a single unlocked recipe, cycling stays put")
    func cyclingWithOneRecipe() {
        let onlyCookie = [RecipeCatalog.recipe(for: .chocolateChipCookie)]
        #expect(RecipeBookModalView.cycled(from: .chocolateChipCookie, by: 1, in: onlyCookie) == .chocolateChipCookie)
        #expect(RecipeBookModalView.cycled(from: .chocolateChipCookie, by: -1, in: onlyCookie) == .chocolateChipCookie)
    }
}

@MainActor
@Suite("Starting from the modal")
struct RecipeBookModalStartTests {
    @Test("Starting creates exactly one in-progress session with the chosen recipe and duration")
    func startingCreatesOneSession() {
        let clock = TestClock(instant(2026, 8, 15, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        let started = store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 40)
        #expect(started?.recipeID == .chocolateChipCookie)
        #expect(started?.durationMinutes == 40)
        #expect(started?.outcome == .inProgress)

        // A second start while one is in flight is refused, not stacked.
        #expect(store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 40) == nil)
        #expect(store.session.active?.id == started?.id)
    }

    @Test("A locked recipe cannot be started, whatever the input layer sends")
    func lockedRecipeIsRefused() {
        let clock = TestClock(instant(2026, 8, 15, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        #expect(store.startSession(recipeID: .croissant, durationMinutes: 25) == nil)
        #expect(store.session.active == nil)
    }
}
