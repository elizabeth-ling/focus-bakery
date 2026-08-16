import SwiftUI

@main
struct FocusBakeryApp: App {
    @State private var store = BakeryStore()
    @State private var notifications = BakeryNotifications(center: .system)
    @State private var feedback = BakeryFeedback(client: .system)
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ChromeFont.register()
    }

    var body: some Scene {
        WindowGroup {
            MainScreenView()
                .modifier(NotificationSync(store: store, notifications: notifications))
                .environment(store)
                .environment(notifications)
                .environment(feedback)
                .task { openBakery() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                openBakery()
            case .background:
                store.noteLeftForeground()
                // The app must not be audible from somewhere the user is not
                // looking (12). Same event as the burn, and the same reading
                // of it: `.inactive` is not a departure.
                feedback.leaveForeground()
                // Reconciled here rather than left to the view update: a
                // departure that dooms the bake has to take its "ready" alert
                // with it before the process is suspended, and a SwiftUI pass
                // may not land first (spec 04).
                notifications.reconcile(with: store)
            // `.inactive` is an incoming call, Control Centre, the app switcher
            // or a Face ID sheet. The user is still here, so it never starts the
            // burn grace (spec 03).
            default:
                break
            }
        }
    }

    private func openBakery() {
        // The day key is re-derived here, not cached at launch: the timezone may
        // have changed while the app was backgrounded.
        store.refreshForCurrentDay()
        // A bake may have finished — or burned — while the app was suspended.
        store.noteReturnedToForeground()
        store.markBakeryOpened()
        // The hum comes back with the room. It fades in over more than a
        // second, which is what keeps it from landing on top of the completion
        // ding a return like this one may also owe (12).
        feedback.enterForeground()
        // Not only for the session: the reminder window is refilled on every
        // return, and today has just been marked as one the user showed up for.
        notifications.reconcile(with: store)
        // Permission can be changed in system settings while the app is away.
        Task { await notifications.refreshAuthorization() }
    }
}

/// Keeps pending notifications mirroring the persisted session.
///
/// A view modifier rather than something hung off the scene, because an
/// `@Observable` dependency is registered by the *view* body pass that reads the
/// value — the same lesson spec 03 learned about presenting an outcome.
///
/// Driven by the state rather than by the call sites that change it, so the
/// screens specs 06 and 10 bring cannot forget to schedule or cancel anything:
/// starting a bake, cancelling one, and one finishing are all just the session
/// changing.
private struct NotificationSync: ViewModifier {
    let store: BakeryStore
    let notifications: BakeryNotifications

    func body(content: Content) -> some View {
        content.onChange(of: store.session, initial: true) { _, _ in
            notifications.reconcile(with: store)
        }
    }
}
