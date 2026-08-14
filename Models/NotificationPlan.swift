import Foundation

/// A local notification the app wants to exist, as a value.
struct PlannedNotification: Equatable, Sendable {
    enum Trigger: Equatable, Sendable {
        /// An absolute instant. A bake ends when it ends, so the alert is pinned
        /// to the same wall-clock arithmetic the timer itself uses (spec 03).
        case instant(Date)
        /// A local wall-clock reading, matched against the calendar at fire
        /// time. "Nine in the morning" means nine wherever the user wakes up.
        case localTime(DateComponents)
    }

    let identifier: String
    let title: String
    let body: String
    let trigger: Trigger
}

/// Which notifications should be pending, given what is on disk.
///
/// Stated as the desired set rather than as a sequence of edits, so scheduling
/// is a pure function of state: every caller reconciles towards the same answer
/// and none of them has to know what the previous one did. Duplicates and stale
/// requests are unreachable rather than merely unlikely (spec 04).
///
/// Pure by design for a second reason too — `UNUserNotificationCenter` cannot be
/// meaningfully exercised off a device, so everything decidable without it is
/// decided here, where tests can reach it.
enum NotificationPlan {
    /// At most one bake is ever in flight (spec 02), so the completion alert
    /// carries one identifier for all time. Adding a request under an
    /// identifier that is already pending replaces it, which is what makes
    /// spec 04's "reschedule rather than duplicate" true by construction rather
    /// than by remembering to cancel first.
    static let completionIdentifier = "bake.completion"

    /// The reminder is a rolling window of dated requests rather than one
    /// repeating request, because a repeating trigger cannot skip a day the user
    /// has already shown up for, and spec 04 rules that out.
    ///
    /// The window is refilled on every foreground, so someone who keeps opening
    /// the app never runs out. Someone who stops gets a week of nudges and then
    /// silence, which is the right end state for a reminder nobody is acting on.
    static let reminderWindowDays = 7

    static func reminderIdentifier(dayOffset: Int) -> String {
        "bakery.reminder.\(dayOffset)"
    }

    /// The whole identifier space this app schedules into. Reconciling means
    /// removing everything here that is not planned, so a request cannot outlive
    /// the state that asked for it.
    static let ownedIdentifiers =
        [completionIdentifier] + (0..<reminderWindowDays).map(reminderIdentifier(dayOffset:))

    /// The alert owed to a bake that is running now *and* will still be alive
    /// when it ends.
    ///
    /// The second half is the interesting one: once the app is backgrounded with
    /// more than the grace left to run, the bake is already doomed under spec
    /// 03's burn policy, and "your bake is ready" for a bake that burned is
    /// exactly the detail spec 04 says makes an app feel thrown together. Asking
    /// the resolver what the session will amount to *at its own end date* answers
    /// that with the policy already in it — including the case the app cannot
    /// come back from, where the user force-quits while away.
    static func completion(for state: SessionState, now: Date) -> PlannedNotification? {
        guard let session = state.active,
              case .baking = state.resolution(at: now),
              state.resolution(at: session.endDate) == .completed
        else { return nil }

        return PlannedNotification(
            identifier: completionIdentifier,
            title: Copy.completionTitle,
            body: Copy.completionBody(for: session.recipeID),
            trigger: .instant(session.endDate)
        )
    }

    /// The next few days of "your bakery's ready to open", skipping any day the
    /// user has already been in.
    ///
    /// In practice that always skips today: the app marks the bakery open on
    /// every foreground, and this is reconciled on the same pass. The rule is
    /// written out anyway because it is the point of the feature — a reminder to
    /// do something you have already done is the fastest way to get notifications
    /// turned off (spec 04).
    static func dailyReminders(
        enabled: Bool,
        at time: TimeOfDay,
        openedToday: Bool,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        guard enabled else { return [] }

        return (0..<reminderWindowDays).compactMap { dayOffset in
            guard !(dayOffset == 0 && openedToday),
                  let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let fireDate = calendar.date(
                      bySettingHour: time.hour, minute: time.minute, second: 0, of: day
                  ),
                  fireDate > now
            else { return nil }

            return PlannedNotification(
                identifier: reminderIdentifier(dayOffset: dayOffset),
                title: Copy.reminderTitle,
                body: Copy.reminderBody,
                trigger: .localTime(
                    calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                )
            )
        }
    }

    /// Provisional. Spec 11 writes every string in the app in one voice, in one
    /// pass; this is the notifications' share of it, held here so that pass has
    /// one place to go.
    private enum Copy {
        static let completionTitle = "Fresh out of the oven"

        static func completionBody(for recipeID: RecipeID) -> String {
            "Your \(RecipeCatalog.recipe(for: recipeID).name.lowercased()) is ready, still warm."
        }

        static let reminderTitle = "Your bakery's ready to open"
        static let reminderBody = "The case is empty and the oven's warm. What are we baking today?"
    }
}
