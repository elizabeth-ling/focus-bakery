import Foundation
import Testing
@testable import FocusBakery

@Suite("Recipes and the coin economy")
struct EconomyTests {
    @Test("The catalogue ships 5 or 6 recipes, with the cookie free and every other one priced")
    func catalogueShape() {
        #expect((5...6).contains(RecipeCatalog.all.count))
        #expect(RecipeCatalog.starter == .chocolateChipCookie)
        #expect(Economy.price(for: .chocolateChipCookie) == 0)

        let priced = RecipeCatalog.all.filter { $0.id != RecipeCatalog.starter }
        #expect(priced.allSatisfy { $0.price > 0 })
    }

    @Test("Every recipe names a sprite the atlas pipeline slices")
    func spritesAreDistinctAndNamed() {
        let spriteNames = RecipeCatalog.all.map(\.spriteName)
        #expect(spriteNames.allSatisfy { !$0.isEmpty })
        #expect(Set(spriteNames).count == spriteNames.count)
    }

    @Test("Coins scale with completed minutes and never go negative")
    func coinsForMinutes() {
        #expect(Economy.coins(forCompletedMinutes: 0) == 0)
        #expect(Economy.coins(forCompletedMinutes: 25) == 25 * Economy.coinsPerFocusMinute)
        #expect(Economy.coins(forCompletedMinutes: -10) == 0)
    }

    @Test("A wallet refuses to overspend")
    func walletCannotGoNegative() {
        var wallet = Wallet()
        wallet.earn(50)

        let overspent = wallet.spend(80)
        #expect(overspent == false)
        #expect(wallet.coinBalance == 50)

        let spentExactly = wallet.spend(50)
        #expect(spentExactly)
        #expect(wallet.coinBalance == 0)

        let spentWhileEmpty = wallet.spend(1)
        #expect(spentWhileEmpty == false)
        #expect(wallet.coinBalance == 0)
    }
}

@MainActor
@Suite("Unlocking recipes")
struct UnlockTests {
    @Test("Buying a recipe deducts the price and unlocks it")
    func buyingDeductsAndUnlocks() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 90)
        clock.advance(hours: 1.5)
        store.finishActiveSession(as: .completed)

        #expect(store.unlock(.croissant))
        #expect(store.progress.wallet.coinBalance == 90 - Economy.price(for: .croissant))
        #expect(store.isUnlocked(.croissant))
        #expect(store.unlockedRecipes.map(\.id) == [.chocolateChipCookie, .croissant])
    }

    @Test("An unaffordable recipe leaves the wallet and the book untouched")
    func unaffordableUnlockIsRefused() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        #expect(store.unlock(.cake) == false)
        #expect(store.progress.wallet.coinBalance == 0)
        #expect(store.isUnlocked(.cake) == false)
    }

    @Test("Buying the same recipe twice is refused and does not double-charge")
    func doubleUnlockIsRefused() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 200)
        clock.advance(hours: 4)
        store.finishActiveSession(as: .completed)

        #expect(store.unlock(.croissant))
        let afterFirst = store.progress.wallet.coinBalance
        #expect(store.unlock(.croissant) == false)
        #expect(store.progress.wallet.coinBalance == afterFirst)
    }

    @Test("Unlocks survive the daily reset and a relaunch")
    func unlocksSurviveResetAndRelaunch() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: directory, clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 90)
        clock.advance(hours: 1.5)
        store.finishActiveSession(as: .completed)
        #expect(store.unlock(.croissant))

        clock.advance(hours: 24)
        store.refreshForCurrentDay()

        let relaunched = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(relaunched.isUnlocked(.croissant))
        #expect(relaunched.today.displayCase.isEmpty)
    }
}
