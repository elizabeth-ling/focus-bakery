import Foundation
import Testing
@testable import FocusBakery

/// Spec 13's first criterion: every toggle takes effect immediately and
/// **persists across relaunch**.
///
/// Immediacy is asserted where it is felt — `BakeryFeedbackTests` for the hum
/// and the cues, `BakeryNotificationsTests` for the reminder. What is left is
/// the relaunch, and a relaunch is exactly this: a fresh `Settings` reading a
/// domain a previous one wrote.
@Suite("Settings persistence")
struct SettingsTests {
    /// A fresh install. The defaults are a decision — sound and haptics on
    /// because the app is a place and should sound like one (12); the daily
    /// reminder off because permission is spent on the completion alert and not
    /// on a nudge nobody asked for (04).
    @Test("A fresh install starts with the intended defaults")
    func freshInstallDefaults() {
        let settings = Settings(defaults: makeTemporaryDefaults())
        #expect(settings.soundEnabled)
        #expect(settings.hapticsEnabled)
        #expect(!settings.dailyReminderEnabled)
        #expect(settings.dailyReminderTime == .defaultReminder)
    }

    /// The bug this is really guarding. `bool(forKey:)` cannot tell "off" from
    /// "never set", so a default-on toggle switched off would come back on at
    /// every launch — the user turning the sound off and finding it on again
    /// tomorrow. `Settings` reads through `object(forKey:)` for exactly this,
    /// and nothing else in the suite would notice if that changed.
    @Test("Every toggle survives a relaunch, including the ones switched off")
    func togglesSurviveRelaunch() {
        let defaults = makeTemporaryDefaults()

        let before = Settings(defaults: defaults)
        before.soundEnabled = false
        before.hapticsEnabled = false
        before.dailyReminderEnabled = true
        before.dailyReminderTime = TimeOfDay(hour: 19, minute: 30)

        // The relaunch: nothing carried over but the domain itself.
        let after = Settings(defaults: defaults)
        #expect(!after.soundEnabled)
        #expect(!after.hapticsEnabled)
        #expect(after.dailyReminderEnabled)
        #expect(after.dailyReminderTime == TimeOfDay(hour: 19, minute: 30))

        // And back again, so the test cannot pass by everything simply being
        // false after a write.
        after.soundEnabled = true
        #expect(Settings(defaults: defaults).soundEnabled)
    }

    /// A hand-edited or stale preference costs the user a wrong reminder time
    /// and never a crash (`TimeOfDay` clamps rather than rejects).
    @Test("A nonsensical stored time is clamped rather than trusted")
    func aCorruptTimeIsClamped() {
        let defaults = makeTemporaryDefaults()
        defaults.set(99_999, forKey: "dailyReminderMinutes")
        let settings = Settings(defaults: defaults)
        #expect(settings.dailyReminderTime.hour == 23)
        #expect(settings.dailyReminderTime.minute == 59)

        defaults.set(-42, forKey: "dailyReminderMinutes")
        #expect(Settings(defaults: defaults).dailyReminderTime == TimeOfDay(hour: 0, minute: 0))
    }
}
