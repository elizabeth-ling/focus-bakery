import Foundation
import Testing
import UserNotifications
@testable import FocusBakery

/// A stand-in for `UNUserNotificationCenter`, faithful in the one respect the
/// app leans on: adding a request under an identifier that is already pending
/// replaces it rather than adding a second.
@MainActor
final class FakeNotificationCenter {
    private(set) var pending: [String: UNNotificationRequest] = [:]
    private(set) var clearedDelivered: [String] = []
    private(set) var authorizationRequests = 0

    var status: UNAuthorizationStatus = .notDetermined
    /// What the system reports once the prompt has been answered.
    var statusAfterRequest: UNAuthorizationStatus = .authorized

    var client: NotificationCenterClient {
        NotificationCenterClient(
            add: { [self] request in pending[request.identifier] = request },
            removePending: { [self] identifiers in
                identifiers.forEach { pending.removeValue(forKey: $0) }
            },
            removeDelivered: { [self] identifiers in clearedDelivered += identifiers },
            pendingIdentifiers: { [self] in Array(pending.keys) },
            status: { [self] in status },
            requestAuthorization: { [self] in
                authorizationRequests += 1
                status = statusAfterRequest
                return status
            },
            installPresentationDelegate: {}
        )
    }

    func trigger(for identifier: String) -> UNNotificationTrigger? {
        pending[identifier]?.trigger
    }
}

/// Spec 04's lifecycle rules, driven through the object that talks to the
/// system — what would have been scheduled, and what would have been taken away.
@MainActor
@Suite("Bakery notifications")
struct BakeryNotificationsTests {
    private let center = FakeNotificationCenter()
    private let clock = TestClock(instant(2026, 8, 14, 9))
    private let settings = Settings(defaults: makeTemporaryDefaults())
    private let notifications: BakeryNotifications

    init() {
        notifications = BakeryNotifications(
            center: center.client,
            settings: settings,
            clock: clock.wallClock
        )
    }

    private func bake(minutes: Int = 25) -> SessionState {
        SessionState(
            active: BakeSession(
                recipeID: .chocolateChipCookie,
                startDate: clock.now,
                durationMinutes: minutes
            )
        )
    }

    /// Seconds from now to the alert, as the system recorded them.
    private var completionSeconds: Int? {
        (center.trigger(for: NotificationPlan.completionIdentifier)
            as? UNTimeIntervalNotificationTrigger)
            .map { Int($0.timeInterval.rounded()) }
    }

    // MARK: - Completion alert

    @Test("A running bake becomes one pending request, due when the bake is")
    func schedulesTheCompletionAlert() {
        notifications.reconcile(session: bake(), openedToday: true)

        #expect(Array(center.pending.keys) == [NotificationPlan.completionIdentifier])
        #expect(completionSeconds == 25 * 60)
    }

    @Test("Start, cancel, start again — exactly one pending completion request")
    func restartingLeavesOneRequest() {
        notifications.reconcile(session: bake(), openedToday: true)
        notifications.reconcile(session: SessionState(), openedToday: true)

        #expect(center.pending.isEmpty)

        clock.advance(minutes: 2)
        notifications.reconcile(session: bake(minutes: 50), openedToday: true)
        // And again with no change at all: reconciling is not an "add".
        notifications.reconcile(session: bake(minutes: 50), openedToday: true)

        #expect(center.pending.count == 1)
        #expect(completionSeconds == 50 * 60)
    }

    @Test("Backgrounding mid-bake takes the alert with it")
    func departureCancelsTheCompletionAlert() {
        var session = bake()
        notifications.reconcile(session: session, openedToday: true)
        #expect(center.pending.count == 1)

        // The bake is doomed the moment the app is backgrounded with more than
        // the grace left to run, and the app may never get another chance to
        // withdraw the alert — the user can force-quit from here.
        session.leftForegroundAt = clock.now
        notifications.reconcile(session: session, openedToday: true)

        #expect(center.pending.isEmpty)
    }

    // MARK: - Daily reminder

    @Test("The daily reminder respects its configured time and its off switch")
    func dailyReminderFollowsItsSettings() {
        settings.dailyReminderEnabled = true
        // Later today than the clock reads, so the window starts with today.
        settings.dailyReminderTime = TimeOfDay(hour: 19, minute: 30)

        notifications.reconcile(session: SessionState(), openedToday: false)

        #expect(center.pending.count == NotificationPlan.reminderWindowDays)
        let trigger = center.trigger(for: NotificationPlan.reminderIdentifier(dayOffset: 0))
            as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == 19)
        #expect(trigger?.dateComponents.minute == 30)
        // Dated, not repeating: a repeating trigger cannot skip a day.
        #expect(trigger?.repeats == false)

        settings.dailyReminderEnabled = false
        notifications.reconcile(session: SessionState(), openedToday: false)

        #expect(center.pending.isEmpty)
    }

    @Test("A bake and a reminder coexist without disturbing each other")
    func completionAndRemindersCoexist() {
        settings.dailyReminderEnabled = true
        settings.dailyReminderTime = TimeOfDay(hour: 19, minute: 30)
        notifications.reconcile(session: bake(), openedToday: true)

        let reminders = center.pending.keys.filter { $0 != NotificationPlan.completionIdentifier }
        // Today is skipped because the user is plainly in the app, so the window
        // is one short — and the bake's alert is untouched by any of it.
        #expect(reminders.count == NotificationPlan.reminderWindowDays - 1)
        #expect(completionSeconds == 25 * 60)
    }

    // MARK: - Permission

    @Test("Permission is asked for once and a denial is announced once")
    func denialIsAnnouncedExactlyOnce() async {
        center.statusAfterRequest = .denied

        await notifications.requestAuthorizationForBake()

        #expect(center.authorizationRequests == 1)
        #expect(notifications.denialNotice != nil)
        notifications.acknowledgeDenialNotice()

        // A second bake: the system has already been answered, so it is not
        // asked again, and the user is not told again either.
        await notifications.requestAuthorizationForBake()

        #expect(center.authorizationRequests == 1)
        #expect(notifications.denialNotice == nil)
    }

    @Test("The denial notice does not come back after a relaunch")
    func denialNoticeSurvivesRelaunch() async {
        center.statusAfterRequest = .denied
        await notifications.requestAuthorizationForBake()
        notifications.acknowledgeDenialNotice()

        let relaunched = BakeryNotifications(
            center: center.client,
            settings: settings,
            clock: clock.wallClock
        )
        await relaunched.refreshAuthorization()
        await relaunched.requestAuthorizationForBake()

        #expect(relaunched.authorization == .denied)
        #expect(relaunched.denialNotice == nil)
    }

    @Test("A quiet grant is not reported as a refusal")
    func provisionalAuthorizationIsNotADenial() async {
        center.statusAfterRequest = .provisional

        await notifications.requestAuthorizationForBake()

        #expect(notifications.authorization == .provisional)
        #expect(notifications.denialNotice == nil)
        #expect(settings.hasSeenNotificationNotice == false)
    }

    @Test("A denied bakery still schedules, so a later grant needs no catch-up")
    func schedulingIsIndependentOfPermission() {
        center.status = .denied

        notifications.reconcile(session: bake(), openedToday: true)

        // Nothing in the app asks permission before scheduling: the request is
        // simply not delivered, and completion is resolved from persisted state
        // either way (spec 03).
        #expect(center.pending.count == 1)
    }

    @Test("Acknowledging a bake in the app takes its banner down")
    func acknowledgementClearsTheDeliveredAlert() {
        notifications.clearDeliveredCompletion()

        #expect(center.clearedDelivered == [NotificationPlan.completionIdentifier])
    }
}
