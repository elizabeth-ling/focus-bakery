import Foundation

/// Permanent progression. The daily reset must never touch this file, and it is
/// stored apart from `TodayState` so that damage to today's data cannot cost
/// the user their recipe book (spec 02).
struct ProgressState: Codable, Sendable {
    var wallet = Wallet()
    var unlockedRecipeIDs: Set<RecipeID> = [RecipeCatalog.starter]
    var streak = StreakState()

    init() {}

    /// Every field is optional on the way in and unknown recipe ids are
    /// dropped, so adding a field in a later build -- or retiring a recipe --
    /// degrades to a default instead of failing the decode and wiping
    /// progression.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wallet = try container.decodeIfPresent(Wallet.self, forKey: .wallet) ?? Wallet()
        streak = try container.decodeIfPresent(StreakState.self, forKey: .streak) ?? StreakState()

        let rawUnlocks = try container.decodeIfPresent([String].self, forKey: .unlockedRecipeIDs) ?? []
        unlockedRecipeIDs = Set(rawUnlocks.compactMap(RecipeID.init(rawValue:)))
        unlockedRecipeIDs.insert(RecipeCatalog.starter)
    }
}

/// Today's output and today's ritual — the part that rolls over each morning.
/// Losing this file costs the user today's display case and nothing else.
struct TodayState: Codable, Sendable {
    var displayCase: DisplayCaseDay
    var ritual: DailyRitual
    /// Focus minutes completed today.
    ///
    /// Spec 09 leaves the streak condition unresolved but requires it be
    /// lockable later without a refactor. Minutes plus the treat count plus
    /// `ritual.openedAt` cover all three candidate conditions -- a minutes
    /// target, one completed session, or simply opening the app -- so none of
    /// them needs retained session history to evaluate.
    var focusMinutes: Int = 0

    /// The day both sub-entities belong to. Held once rather than compared
    /// between them, so they cannot drift apart.
    var date: DayKey { displayCase.date }

    init(date: DayKey) {
        displayCase = DisplayCaseDay(date: date)
        ritual = DailyRitual(date: date)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedCase = try container.decodeIfPresent(DisplayCaseDay.self, forKey: .displayCase)
        let storedRitual = try container.decodeIfPresent(DailyRitual.self, forKey: .ritual)
        guard let day = storedCase?.date ?? storedRitual?.date else {
            throw DecodingError.dataCorruptedError(
                forKey: .displayCase,
                in: container,
                debugDescription: "TodayState has neither a display case nor a ritual to take a day from"
            )
        }
        displayCase = storedCase ?? DisplayCaseDay(date: day)
        ritual = storedRitual ?? DailyRitual(date: day)
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 0
    }
}

/// The in-flight bake.
///
/// A single optional slot rather than a collection, which is what makes spec
/// 02's "at most one `.inProgress` session" true by construction instead of by
/// a validation rule somebody has to remember to run.
struct SessionState: Codable, Equatable, Sendable {
    var active: BakeSession?

    /// When the app last left the foreground with this bake in flight.
    ///
    /// Persisted rather than held in memory because the burn has to survive
    /// being killed while away: on the next cold launch this is the only
    /// evidence that the user ever left (spec 03).
    var leftForegroundAt: Date?

    init(active: BakeSession? = nil, leftForegroundAt: Date? = nil) {
        self.active = active
        self.leftForegroundAt = leftForegroundAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decodeIfPresent(BakeSession.self, forKey: .active)
        // An already-resolved session in the live slot is a bug, not state to
        // restore; keeping it would let it be resolved a second time.
        active = stored?.outcome == .inProgress ? stored : nil
        // Meaningless without a bake to burn, and keeping it would apply a stale
        // departure to whatever is started next.
        leftForegroundAt = active == nil
            ? nil
            : try container.decodeIfPresent(Date.self, forKey: .leftForegroundAt)
    }
}

/// The day that just ended, handed back by the rollover.
///
/// The display case is cleared at rollover, but spec 09 evaluates the streak on
/// the same foreground pass and needs the outgoing day's inputs to do it. This
/// carries them across so that evaluation can be added later without changing
/// how the reset works.
struct RetiredDay: Hashable, Sendable {
    let date: DayKey
    let treatCount: Int
    let focusMinutes: Int
    let openedApp: Bool
    let answeredIntention: Bool
}
