import Foundation

/// A local wall-clock time with no date attached.
struct TimeOfDay: Equatable, Sendable {
    /// Nine in the morning: the reminder is the bakery opening, and it wants to
    /// land at the start of a day rather than in the middle of one (spec 04).
    static let defaultReminder = TimeOfDay(hour: 9, minute: 0)

    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.init(minutesFromMidnight: hour * 60 + minute)
    }

    /// Stored as one integer rather than two keys, which cannot then disagree.
    /// Anything outside a day is clamped rather than rejected, so a corrupt
    /// preference costs the user a wrong reminder time and not a crash.
    init(minutesFromMidnight: Int) {
        let clamped = min(max(minutesFromMidnight, 0), 24 * 60 - 1)
        hour = clamped / 60
        minute = clamped % 60
    }

    var minutesFromMidnight: Int { hour * 60 + minute }
}

/// UserDefaults-backed preferences.
///
/// Spec 02 calls this out as the place where UserDefaults is the right tool:
/// a handful of independent toggles, not game state that needs atomic writes or
/// a bounded failure blast radius. Specs 04, 12 and 13 own what goes here.
struct Settings {
    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let soundEnabled = "soundEnabled"
        static let hapticsEnabled = "hapticsEnabled"
        static let dailyReminderEnabled = "dailyReminderEnabled"
        static let dailyReminderMinutes = "dailyReminderMinutes"
        static let hasSeenNotificationNotice = "hasSeenNotificationNotice"
        static let lastBakeDurationMinutes = "lastBakeDurationMinutes"
        static let lastBakeRecipeID = "lastBakeRecipeID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        get { flag(Key.hasCompletedOnboarding, default: false) }
        nonmutating set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    var soundEnabled: Bool {
        get { flag(Key.soundEnabled, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.soundEnabled) }
    }

    var hapticsEnabled: Bool {
        get { flag(Key.hapticsEnabled, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.hapticsEnabled) }
    }

    /// Off until asked for. Permission is requested in context for the
    /// *completion* alert (spec 04), and spending that grant on a daily nudge
    /// the user never asked for is how an app teaches people to deny it.
    var dailyReminderEnabled: Bool {
        get { flag(Key.dailyReminderEnabled, default: false) }
        nonmutating set { defaults.set(newValue, forKey: Key.dailyReminderEnabled) }
    }

    var dailyReminderTime: TimeOfDay {
        get {
            guard let minutes = defaults.object(forKey: Key.dailyReminderMinutes) as? Int else {
                return .defaultReminder
            }
            return TimeOfDay(minutesFromMidnight: minutes)
        }
        nonmutating set {
            defaults.set(newValue.minutesFromMidnight, forKey: Key.dailyReminderMinutes)
        }
    }

    /// Whether the user has been told, once, that completion alerts will not
    /// fire. Persisted so that "once" survives relaunching (spec 04).
    var hasSeenNotificationNotice: Bool {
        get { flag(Key.hasSeenNotificationNotice, default: false) }
        nonmutating set { defaults.set(newValue, forKey: Key.hasSeenNotificationNotice) }
    }

    /// What the recipe book opens showing (spec 10). Clamped on the way out,
    /// so a stale or hand-edited preference is a wrong duration, never an
    /// absurd one.
    var lastBakeDurationMinutes: Int {
        get {
            guard let minutes = defaults.object(forKey: Key.lastBakeDurationMinutes) as? Int else {
                return BakeDuration.defaultMinutes
            }
            return BakeDuration.clamped(minutes)
        }
        nonmutating set { defaults.set(newValue, forKey: Key.lastBakeDurationMinutes) }
    }

    /// Nil until a first bake is started, and nil again if the stored value
    /// stops naming a recipe; the caller falls back to the starter.
    var lastBakeRecipeID: RecipeID? {
        get {
            (defaults.string(forKey: Key.lastBakeRecipeID)).flatMap(RecipeID.init(rawValue:))
        }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Key.lastBakeRecipeID) }
    }

    /// `object(forKey:)` rather than `bool(forKey:)`, which cannot tell "off"
    /// apart from "never set" and would turn every default-on toggle off.
    private func flag(_ key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
