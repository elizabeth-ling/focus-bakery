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

    /// The one place the curve's numbers are legitimately written down twice:
    /// this suite exists to pin `Economy`, so it names what the bands pay.
    /// Everywhere else asks `Economy.coins(forCompletedMinutes:)`.
    @Test("Coins follow the banded curve and never go negative")
    func coinsForMinutes() {
        #expect(Economy.coins(forCompletedMinutes: 0) == 0)
        #expect(Economy.coins(forCompletedMinutes: -10) == 0)

        #expect(Economy.coins(forCompletedMinutes: 5) == 5)
        #expect(Economy.coins(forCompletedMinutes: 15) == 15)
        // 15 at one, then ten at two.
        #expect(Economy.coins(forCompletedMinutes: 25) == 35)
        // 15 at one, thirty at two.
        #expect(Economy.coins(forCompletedMinutes: 45) == 75)
        // ...then the rest at three.
        #expect(Economy.coins(forCompletedMinutes: 50) == 90)
    }

    @Test("The curve rises without a cliff, so no duration is worth stopping short of")
    func curveIsMonotonicAndContinuous() {
        let byMinute = (0...120).map(Economy.coins(forCompletedMinutes:))
        let steps = zip(byMinute, byMinute.dropFirst()).map { $1 - $0 }

        #expect(steps.allSatisfy { $0 > 0 })
        // A band change may raise the per-minute rate but must never hand out a
        // lump sum -- that is the cliff a banded *total* would create.
        #expect(steps.allSatisfy { $0 <= 3 })
    }

    @Test("One deep session out-earns the same minutes chopped into short ones")
    func depthBeatsFarming() {
        let oneLongBake = Economy.coins(forCompletedMinutes: 50)
        let tenShortBakes = 10 * Economy.coins(forCompletedMinutes: 5)

        #expect(oneLongBake > tenShortBakes)
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
    /// Earns by baking rather than by poking the wallet, so the tests spend the
    /// same coins the product does.
    private func storeEarning(
        fromMinutes minutes: Int,
        clock: TestClock,
        directory: URL = makeTemporaryDirectory()
    ) -> BakeryStore {
        let store = BakeryStore(directory: directory, clock: clock.wallClock)
        guard minutes > 0 else { return store }

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: minutes)
        clock.advance(minutes: Double(minutes))
        store.finishActiveSession(as: .completed)
        return store
    }

    @Test("A fresh install has exactly one unlocked recipe: the chocolate-chip cookie")
    func freshInstallHasOnlyTheStarter() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        #expect(store.unlockedRecipes.map(\.id) == [.chocolateChipCookie])
        #expect(store.progress.wallet.coinBalance == 0)
    }

    @Test("Buying a recipe deducts the price and unlocks it")
    func buyingDeductsAndUnlocks() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = storeEarning(fromMinutes: 90, clock: clock)
        let earned = Economy.coins(forCompletedMinutes: 90)

        #expect(store.purchase(.croissant) == .bought)
        #expect(store.progress.wallet.coinBalance == earned - Economy.price(for: .croissant))
        #expect(store.isUnlocked(.croissant))
        #expect(store.unlockedRecipes.map(\.id) == [.chocolateChipCookie, .croissant])
    }

    @Test("An unaffordable recipe reports the shortfall and touches nothing")
    func unaffordableUnlockIsRefused() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = storeEarning(fromMinutes: 25, clock: clock)
        let balance = store.progress.wallet.coinBalance

        let result = store.purchase(.cake)

        #expect(result == .insufficientFunds(coinsShort: Economy.price(for: .cake) - balance))
        #expect(store.progress.wallet.coinBalance == balance)
        #expect(store.isUnlocked(.cake) == false)
    }

    @Test("Buying the same recipe twice is refused and does not double-charge")
    func doubleUnlockIsRefused() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = storeEarning(fromMinutes: 200, clock: clock)

        #expect(store.purchase(.croissant) == .bought)
        let afterFirst = store.progress.wallet.coinBalance

        #expect(store.purchase(.croissant) == .alreadyOwned)
        #expect(store.progress.wallet.coinBalance == afterFirst)
    }

    @Test("The starter is owned outright rather than bought for nothing")
    func starterIsAlreadyOwned() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        #expect(store.purchase(.chocolateChipCookie) == .alreadyOwned)
    }

    @Test("The book lists locked recipes with their price and what is still owed")
    func bookShowsLockedRecipesAndShortfall() throws {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = storeEarning(fromMinutes: 90, clock: clock)
        let balance = store.progress.wallet.coinBalance

        let book = store.recipeBook
        #expect(book.map(\.id) == RecipeCatalog.all.map(\.id))

        let cookie = try #require(book.first { $0.id == .chocolateChipCookie })
        #expect(cookie.isUnlocked)

        let croissant = try #require(book.first { $0.id == .croissant })
        #expect(croissant.isUnlocked == false)
        #expect(croissant.recipe.price == Economy.price(for: .croissant))
        #expect(croissant.isAffordable)
        #expect(croissant.coinsShort == 0)

        let cake = try #require(book.first { $0.id == .cake })
        #expect(cake.isAffordable == false)
        #expect(cake.coinsShort == Economy.price(for: .cake) - balance)
    }

    @Test("Unlocks survive the daily reset and a relaunch")
    func unlocksSurviveResetAndRelaunch() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = storeEarning(fromMinutes: 90, clock: clock, directory: directory)

        #expect(store.purchase(.croissant) == .bought)
        let balance = store.progress.wallet.coinBalance

        clock.advance(hours: 24)
        store.refreshForCurrentDay()

        let relaunched = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(relaunched.isUnlocked(.croissant))
        #expect(relaunched.progress.wallet.coinBalance == balance)
        #expect(relaunched.today.displayCase.isEmpty)
    }

    @Test("Unlocks survive a cold start with a bake still in flight")
    func unlocksSurviveColdStartMidBake() {
        let directory = makeTemporaryDirectory()
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = storeEarning(fromMinutes: 90, clock: clock, directory: directory)

        #expect(store.purchase(.croissant) == .bought)
        let balance = store.progress.wallet.coinBalance

        let inFlight = store.startSession(recipeID: .croissant, durationMinutes: 25)
        #expect(inFlight != nil)
        clock.advance(minutes: 5)

        let relaunched = BakeryStore(directory: directory, clock: clock.wallClock)
        #expect(relaunched.isUnlocked(.croissant))
        #expect(relaunched.progress.wallet.coinBalance == balance)
        // The bake it was bought for is still running, and still its own.
        #expect(relaunched.session.active?.id == inFlight?.id)
        #expect(relaunched.session.active?.recipeID == .croissant)
    }

    @Test("A burned session pays for nothing, so a pending purchase stays out of reach")
    func burnedSessionEarnsNothing() {
        let clock = TestClock(instant(2026, 8, 14, 9))
        let store = BakeryStore(directory: makeTemporaryDirectory(), clock: clock.wallClock)

        store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 90)
        clock.advance(minutes: 90)
        store.finishActiveSession(as: .burned)

        #expect(store.progress.wallet.coinBalance == 0)
        #expect(store.today.displayCase.isEmpty)
        #expect(store.purchase(.croissant) == .insufficientFunds(coinsShort: Economy.price(for: .croissant)))
    }
}
