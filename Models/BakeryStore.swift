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

    /// What the in-flight bake amounts to right now. Re-derived from the stored
    /// `endDate` on every read, so the countdown is a display and never a
    /// counter (spec 03).
    var resolution: SessionResolution { session.resolution(at: clock.now()) }

    /// A bake that finished while the user was away and has not been shown to
    /// them yet — the celebration, or the bad news, owed on return.
    ///
    /// Only the lazy path sets this. A bake the user deliberately cancelled was
    /// just confirmed by them and needs no announcing.
    private(set) var pendingOutcome: BakeSession?

    /// Returns nil when a bake is already in flight or the recipe is locked.
    @discardableResult
    func startSession(recipeID: RecipeID, durationMinutes: Int) -> BakeSession? {
        guard session.active == nil, isUnlocked(recipeID) else { return nil }
        let started = BakeSession(
            recipeID: recipeID,
            startDate: clock.now(),
            durationMinutes: durationMinutes
        )
        // Replaced wholesale rather than assigned field by field, so the bake and
        // the departure that can burn it are never set independently.
        session = SessionState(active: started)
        sessionStore.save(session)
        return started
    }

    /// Records that the app left the foreground with a bake in flight, starting
    /// the burn grace.
    ///
    /// Written to disk immediately: the user may never bring the app back, and
    /// the next launch has no other way to know they left.
    func noteLeftForeground() {
        // The grace runs from the *first* departure. A second background event
        // without an intervening return must not extend it.
        guard session.active != nil, session.leftForegroundAt == nil else { return }
        session.leftForegroundAt = clock.now()
        sessionStore.save(session)
    }

    /// Resolves whatever happened while the app was away, then spends the
    /// departure if the bake survived it.
    ///
    /// The grace is spent per departure and never banked towards the next one.
    /// Clearing lives here rather than in `resolveInFlightSession` because the
    /// display tick keeps running for a moment after the app is backgrounded,
    /// and clearing there erases the very departure that is supposed to burn the
    /// bake.
    @discardableResult
    func noteReturnedToForeground() -> BakeSession? {
        let resolved = resolveInFlightSession()
        if resolved == nil { clearDeparture() }
        return resolved
    }

    /// Applies the burn/complete policy to the in-flight bake. Returns the
    /// session it resolved, or nil when nothing was in flight or the bake is
    /// still going.
    ///
    /// Called on launch, on every foreground, and on each display tick, which is
    /// how a bake that ended while the app was suspended resolves lazily on
    /// return. Awarding stays exactly-once because whichever call arrives second
    /// finds an empty slot.
    @discardableResult
    func resolveInFlightSession() -> BakeSession? {
        let resolved: BakeSession?
        switch resolution {
        case .idle, .baking:
            return nil
        case .completed:
            resolved = finishActiveSession(as: .completed)
        case .burned:
            resolved = finishActiveSession(as: .burned)
        }
        pendingOutcome = resolved
        return resolved
    }

    func acknowledgeOutcome() {
        pendingOutcome = nil
    }

    private func clearDeparture() {
        guard session.leftForegroundAt != nil else { return }
        session.leftForegroundAt = nil
        sessionStore.save(session)
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

        session = SessionState()
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
