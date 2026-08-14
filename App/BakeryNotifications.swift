import Foundation
import Observation
import UserNotifications

/// The app's one point of contact with `UNUserNotificationCenter`.
///
/// It decides nothing: what should be pending is `NotificationPlan`'s answer,
/// and this brings the system into line with it. Keeping the policy pure is what
/// makes any of spec 04 testable, since the center itself cannot be judged off a
/// device.
@MainActor
@Observable
final class BakeryNotifications {
    /// Last known permission. Re-read on every foreground rather than cached:
    /// the user can change it in system settings while the app is away.
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    /// The one-time "alerts are off" notice, or nil once it has been shown.
    ///
    /// Mirrors `BakeryStore.pendingOutcome` — news the app owes the user exactly
    /// once, cleared by acknowledging it.
    private(set) var denialNotice: String?

    private let center: NotificationCenterClient
    private let settings: Settings
    private let clock: WallClock

    /// The center is passed rather than defaulted: a default argument is
    /// evaluated outside this actor, and `.system` belongs to it.
    ///
    /// Installing the delegate here is deliberate — it has to be in place before
    /// launch finishes to catch an app opened from a notification, and this
    /// object is built with the app's `@State`, which is early enough.
    init(
        center: NotificationCenterClient,
        settings: Settings = Settings(),
        clock: WallClock = .system
    ) {
        self.center = center
        self.settings = settings
        self.clock = clock
        center.installPresentationDelegate()
    }

    // MARK: - Permission

    func refreshAuthorization() async {
        authorization = await center.status()
    }

    /// Asks for permission at the moment the payoff is obvious — the start of a
    /// bake, which is the thing the completion alert is for (specs 04, 11).
    /// Never on cold launch.
    ///
    /// It is also where the user is told, once, if alerts cannot be delivered:
    /// they have just started the thing the alert was for, so it is the one
    /// moment the fact is worth their attention. Everywhere else it would be a
    /// nag, and the app works completely without it either way.
    func requestAuthorizationForBake() async {
        authorization = authorization == .notDetermined
            ? await center.requestAuthorization()
            : await center.status()

        guard !authorization.deliversAlerts, !settings.hasSeenNotificationNotice else { return }
        // Recorded when shown rather than when acknowledged. Being killed with
        // the notice on screen costs the user a sentence; the other order risks
        // showing it twice, which is the nagging spec 04 rules out.
        settings.hasSeenNotificationNotice = true
        denialNotice = Copy.alertsAreOff
    }

    func acknowledgeDenialNotice() {
        denialNotice = nil
    }

    // MARK: - Scheduling

    /// Brings pending requests in line with what is on disk.
    ///
    /// Idempotent, and derived from state rather than from what just happened,
    /// so launch, foreground, backgrounding, starting a bake and cancelling one
    /// can all call it without any of them having to agree on whose job it is —
    /// and a screen added later cannot forget to schedule anything.
    func reconcile(session: SessionState, openedToday: Bool) {
        let now = clock.now()
        let planned = [NotificationPlan.completion(for: session, now: now)].compactMap { $0 }
            + NotificationPlan.dailyReminders(
                enabled: settings.dailyReminderEnabled,
                at: settings.dailyReminderTime,
                openedToday: openedToday,
                now: now,
                calendar: clock.calendar()
            )

        let wanted = Set(planned.map(\.identifier))
        center.removePending(NotificationPlan.ownedIdentifiers.filter { !wanted.contains($0) })
        // Adding under an identifier that is already pending replaces it, so
        // this is a reschedule and never a duplicate (spec 04).
        for notification in planned {
            center.add(request(for: notification, now: now))
        }
    }

    /// Takes the completion banner down once the app itself has delivered the
    /// news (spec 04).
    func clearDeliveredCompletion() {
        center.removeDelivered([NotificationPlan.completionIdentifier])
    }

    /// What is actually pending. For the by-hand device pass spec 04 requires,
    /// where "exactly one pending completion request" has to be seen to be
    /// believed.
    func pendingIdentifiers() async -> [String] {
        await center.pendingIdentifiers()
    }

    private func request(for planned: PlannedNotification, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.body = planned.body
        content.sound = .default

        let trigger: UNNotificationTrigger
        switch planned.trigger {
        case .instant(let date):
            // Counted forwards from now rather than matched against the
            // calendar, so the alert keeps the same distance away that the bake
            // does. The floor only satisfies the trigger's own rule that the
            // interval be positive; the plan has already established that this
            // bake ends in the future.
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(date.timeIntervalSince(now), 1),
                repeats: false
            )
        case .localTime(let components):
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        return UNNotificationRequest(
            identifier: planned.identifier,
            content: content,
            trigger: trigger
        )
    }

    /// Provisional, like the rest of the app's strings, until spec 11's copy
    /// pass writes them all in one voice.
    private enum Copy {
        static let alertsAreOff = """
            We won't be able to tell you when a bake is done. The timer still \
            runs either way — come back and the bakery will be where you left it.
            """
    }
}

extension BakeryNotifications {
    /// The store is the state notifications mirror, so the glue between them
    /// lives in one place instead of in each caller.
    func reconcile(with store: BakeryStore) {
        reconcile(session: store.session, openedToday: store.today.ritual.openedAt != nil)
    }
}

extension UNAuthorizationStatus {
    /// Whether a scheduled alert will actually reach the user.
    ///
    /// `.provisional` delivers quietly, straight to Notification Center, which
    /// is not "off" and must not be reported as such. `.ephemeral` is App
    /// Clip-only and cannot occur here, but it is a grant, and an unknown future
    /// status is likelier to be another grant than another refusal. Nothing in
    /// the app depends on delivery, so the only cost of guessing generously is
    /// staying quiet (spec 04).
    var deliversAlerts: Bool {
        switch self {
        case .denied, .notDetermined: false
        case .authorized, .provisional, .ephemeral: true
        @unknown default: true
        }
    }
}

/// Suppresses banners while the app is on screen.
///
/// There is deliberately no tap handler: opening from a notification makes the
/// scene active, and the app resolves the bake from persisted state on every
/// foreground and presents the celebration itself (spec 03). A handler here
/// would be a second path to the same place, and the notification would start
/// looking like something completion depends on.
@MainActor
final class NotificationPresentation: NSObject, UNUserNotificationCenterDelegate {
    /// `UNUserNotificationCenter` holds its delegate weakly and this object has
    /// no state worth owning elsewhere, so it retains itself.
    private static let shared = NotificationPresentation()

    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    /// The app is in front of the user: it has just resolved the bake itself, so
    /// a banner over the top of the celebration would be the app announcing
    /// something the user is already looking at.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}

/// The `UNUserNotificationCenter` calls this app makes, as closures.
///
/// An injection point rather than an abstraction: it exists so tests can assert
/// what *would* have been scheduled, which is the only part of spec 04 that can
/// be judged without a device in your hand.
@MainActor
struct NotificationCenterClient {
    var add: (UNNotificationRequest) -> Void
    var removePending: ([String]) -> Void
    var removeDelivered: ([String]) -> Void
    var pendingIdentifiers: () async -> [String]
    var status: () async -> UNAuthorizationStatus
    var requestAuthorization: () async -> UNAuthorizationStatus
    var installPresentationDelegate: () -> Void

    static let system = NotificationCenterClient(
        add: { request in
            // Fire and forget. The failure modes are a malformed request, which
            // is a programming error, and the daemon being briefly unavailable,
            // which the next reconcile fixes. Nothing waits on the result:
            // completion is resolved from persisted state (spec 03).
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        },
        removePending: {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: $0)
        },
        removeDelivered: {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: $0)
        },
        pendingIdentifiers: {
            await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
        },
        status: {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        },
        requestAuthorization: {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            // The granted flag answers a narrower question than the app is
            // asking. A provisional grant, and a second request after a denial,
            // both report something the settings read gets right.
            return await center.notificationSettings().authorizationStatus
        },
        installPresentationDelegate: NotificationPresentation.install
    )
}
