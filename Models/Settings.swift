import Foundation

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

    var dailyReminderEnabled: Bool {
        get { flag(Key.dailyReminderEnabled, default: false) }
        nonmutating set { defaults.set(newValue, forKey: Key.dailyReminderEnabled) }
    }

    /// `object(forKey:)` rather than `bool(forKey:)`, which cannot tell "off"
    /// apart from "never set" and would turn every default-on toggle off.
    private func flag(_ key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
