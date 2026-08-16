import Foundation
import Testing
@testable import FocusBakery

@Suite("The recipe-book modal")
struct RecipeBookModalTests {
    /// The book as the store hands it over: the whole catalogue, priced against
    /// a balance, with `unlocked` owned outright.
    private func book(unlocked: Set<RecipeID>, balance: Int = 0) -> [RecipeBookEntry] {
        RecipeCatalog.all.map { recipe in
            RecipeBookEntry(
                recipe: recipe,
                isUnlocked: unlocked.contains(recipe.id),
                coinsShort: unlocked.contains(recipe.id) ? 0 : max(0, recipe.price - balance)
            )
        }
    }

    @Test("Arrows cycle through every page and wrap at both ends")
    func cyclingWraps() throws {
        let pages = book(unlocked: [.chocolateChipCookie])
        let first = try #require(pages.first?.id)
        let last = try #require(pages.last?.id)

        #expect(RecipeBookModalView.cycled(from: first, by: 1, in: pages) == pages[1].id)
        #expect(RecipeBookModalView.cycled(from: last, by: 1, in: pages) == first)
        #expect(RecipeBookModalView.cycled(from: first, by: -1, in: pages) == last)
    }

    /// The reversal spec 10 records: the book is browsed whole, so a fresh
    /// install with one unlock still has five pages to turn to.
    @Test("Cycling reaches the locked recipes, not just the unlocked ones")
    func cyclingReachesLockedRecipes() {
        let pages = book(unlocked: [.chocolateChipCookie])
        var seen: Set<RecipeID> = []
        var id = RecipeCatalog.starter

        for _ in RecipeCatalog.all.indices {
            seen.insert(id)
            id = RecipeBookModalView.cycled(from: id, by: 1, in: pages)
        }

        #expect(seen == Set(RecipeCatalog.all.map(\.id)))
        // A full lap comes home rather than drifting.
        #expect(id == RecipeCatalog.starter)
    }

    @Test("Cycling never leaves the book, whatever page it is asked from")
    func cyclingStaysInTheBook() {
        let pages = book(unlocked: [.chocolateChipCookie, .croissant])
        let ids = Set(pages.map(\.id))
        for id in RecipeID.allCases {
            for delta in [-1, 1] {
                #expect(ids.contains(RecipeBookModalView.cycled(from: id, by: delta, in: pages)))
            }
        }
    }

    @Test("A locked page carries the price and the shortfall the buy button shows")
    func lockedPageCarriesPriceAndShortfall() throws {
        let pages = book(unlocked: [.chocolateChipCookie], balance: 100)

        let croissant = try #require(pages.first { $0.id == .croissant })
        #expect(croissant.isUnlocked == false)
        #expect(croissant.recipe.price == Economy.price(for: .croissant))
        #expect(croissant.isAffordable)

        let cake = try #require(pages.first { $0.id == .cake })
        #expect(cake.isAffordable == false)
        #expect(cake.coinsShort == Economy.price(for: .cake) - 100)
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

    /// Buying is what turns the page the user is already looking at from a
    /// price into a stepper: the modal holds the recipe, and the entry it reads
    /// for that recipe flips to unlocked without the book being reopened.
    @Test("Buying the page you are on unlocks it and makes it startable in place")
    func purchasingUnlocksThePageInPlace() throws {
        let clock = TestClock(instant(2026, 8, 15, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 90)
        clock.advance(minutes: 90)
        store.finishActiveSession(as: .completed)

        let before = try #require(store.recipeBook.first { $0.id == .croissant })
        #expect(before.isUnlocked == false)
        #expect(store.startSession(recipeID: .croissant, durationMinutes: 25) == nil)

        #expect(store.purchase(.croissant) == .bought)

        let after = try #require(store.recipeBook.first { $0.id == .croissant })
        #expect(after.isUnlocked)
        #expect(store.startSession(recipeID: .croissant, durationMinutes: 25)?.recipeID == .croissant)
    }
}
