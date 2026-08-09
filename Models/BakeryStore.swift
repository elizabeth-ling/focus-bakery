import Foundation
import Observation

/// Owns the app's persisted state and every write to it.
///
/// The three slices are loaded and saved independently so that the permanent
/// recipe book, today's output, and an in-flight bake each fail alone.
@MainActor
@Observable
final class BakeryStore {
    private(set) var progress: ProgressState
    private(set) var today: TodayState
    private(set) var session: SessionState

    private let clock: WallClock
    private let progressStore: JSONFileStore<ProgressState>
    private let todayStore: JSONFileStore<TodayState>
    private let sessionStore: JSONFileStore<SessionState>

    /// Held until `refreshForCurrentDay()` drains it, so a rollover triggered by
    /// a session finishing just after midnight is still reported rather than
    /// lost between foreground events.
    private var pendingRetiredDay: RetiredDay?

    init(directory: URL = StoreLocation.defaultDirectory(), clock: WallClock = .system) {
        let currentDay = clock.today
        let progressStore = JSONFileStore(
            url: directory.appending(path: "progress.json"),
            fallback: { ProgressState() }
        )
        let todayStore = JSONFileStore(
            url: directory.appending(path: "today.json"),
            fallback: { TodayState(date: currentDay) }
        )
        let sessionStore = JSONFileStore(
            url: directory.appending(path: "session.json"),
            fallback: { SessionState() }
        )

        self.clock = clock
        self.progressStore = progressStore
        self.todayStore = todayStore
        self.sessionStore = sessionStore
        progress = progressStore.load()
        today = todayStore.load()
        session = sessionStore.load()
    }

    // MARK: - Day rollover

    /// Re-derives the current local day and rolls today's state over if the day
    /// has advanced. Returns the day that was retired, or nil if none was.
    ///
    /// Lazy by design: spec 02 has no background job, so this runs on launch and
    /// on every foreground.
    @discardableResult
    func refreshForCurrentDay() -> RetiredDay? {
        rollOverIfNeeded()
        defer { pendingRetiredDay = nil }
        return pendingRetiredDay
    }

    /// Touches `today` and nothing else. The recipe book, the wallet, the streak
    /// and an in-flight bake are all in other slices and are not written here --
    /// which is the whole reason they live in other slices.
    private func rollOverIfNeeded() {
        let currentDay = clock.today
        // Strictly later, not merely different. Travelling west moves the local
        // day backwards, and treating that as a rollover would clear a case the
        // user is still filling, then clear it again on the way home.
        guard currentDay > today.date else { return }

        pendingRetiredDay = RetiredDay(
            date: today.date,
            treatCount: today.displayCase.totalCount,
            focusMinutes: today.focusMinutes,
            openedApp: today.ritual.openedAt != nil,
            answeredIntention: today.ritual.hasAnsweredIntention
        )
        today = TodayState(date: currentDay)
        todayStore.save(today)
    }

    // MARK: - Recipe book

    func isUnlocked(_ id: RecipeID) -> Bool {
        progress.unlockedRecipeIDs.contains(id)
    }

    var unlockedRecipes: [Recipe] {
        RecipeCatalog.all.filter { isUnlocked($0.id) }
    }

    /// Spends the price and unlocks permanently. Reports failure and leaves both
    /// the wallet and the book untouched when the balance is short (spec 07).
    @discardableResult
    func unlock(_ id: RecipeID) -> Bool {
        guard !isUnlocked(id), progress.wallet.spend(Economy.price(for: id)) else { return false }
        progress.unlockedRecipeIDs.insert(id)
        progressStore.save(progress)
        return true
    }

    // MARK: - Sessions

    /// Returns nil when a bake is already in flight or the recipe is locked.
    @discardableResult
    func startSession(recipeID: RecipeID, durationMinutes: Int) -> BakeSession? {
        guard session.active == nil, isUnlocked(recipeID) else { return nil }
        let started = BakeSession(
            recipeID: recipeID,
            startDate: clock.now(),
            durationMinutes: durationMinutes
        )
        session.active = started
        sessionStore.save(session)
        return started
    }

    /// Clears the live slot and applies the outcome.
    ///
    /// Returns nil when nothing is in flight, which is what makes the
    /// double-award spec 03 warns about impossible: of the live path and the
    /// foreground path, whichever arrives second finds an empty slot.
    @discardableResult
    func finishActiveSession(as outcome: BakeSession.Outcome) -> BakeSession? {
        guard outcome != .inProgress, var finished = session.active else { return nil }
        finished.outcome = outcome

        session.active = nil
        sessionStore.save(session)

        guard outcome == .completed else { return finished }

        // A bake started yesterday belongs to the day it finishes in (spec 08),
        // so settle the day before crediting anything to it.
        rollOverIfNeeded()

        progress.wallet.earn(Economy.coins(forCompletedMinutes: finished.durationMinutes))
        progressStore.save(progress)

        // Recorded now rather than when the baker finishes the deliver walk, so
        // being killed mid-walk cannot lose it. Spec 08 governs when the treat
        // becomes *visible*, which is presentation, not data.
        today.displayCase.add(finished.recipeID)
        today.focusMinutes += finished.durationMinutes
        todayStore.save(today)

        return finished
    }

    // MARK: - Daily ritual

    func markBakeryOpened() {
        guard today.ritual.openedAt == nil else { return }
        today.ritual.openedAt = clock.now()
        todayStore.save(today)
    }

    func recordIntention(_ text: String) {
        today.ritual.intentionText = text
        todayStore.save(today)
    }

    func recordReflection(_ text: String) {
        today.ritual.reflectionText = text
        today.ritual.closedAt = clock.now()
        todayStore.save(today)
    }
}
