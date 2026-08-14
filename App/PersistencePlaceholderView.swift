import SwiftUI
import UserNotifications

/// Temporary. Spec 06 replaces this with the bakery room; until then it exists
/// so persistence and the timer can be exercised by hand on a device — start a
/// bake, leave, come back late, kill the app, and check what survived.
struct PersistencePlaceholderView: View {
    @Environment(BakeryStore.self) private var store
    @Environment(BakeryNotifications.self) private var notifications
    @State private var isShowingOutcome = false
    @State private var isShowingDenialNotice = false

    var body: some View {
        // Read in the body itself, not only inside the alert's closures: an
        // @Observable dependency is registered by the body pass that reads the
        // value, and one touched only inside a closure never registers one — so
        // an outcome resolved at launch would never reach the screen.
        let outcome = store.pendingOutcome
        let denialNotice = notifications.denialNotice

        List {
            Section("Today") {
                LabeledContent("Day", value: "\(store.today.date.year)-\(store.today.date.month)-\(store.today.date.day)")
                LabeledContent("Treats baked", value: "\(store.today.displayCase.totalCount)")
                LabeledContent("Focus minutes", value: "\(store.today.focusMinutes)")
            }

            Section("Progress") {
                LabeledContent("Coins", value: "\(store.progress.wallet.coinBalance)")
                LabeledContent("Unlocked recipes", value: "\(store.progress.unlockedRecipeIDs.count) of \(RecipeCatalog.all.count)")
                LabeledContent("Streak", value: "\(store.progress.streak.currentStreak)")
            }

            BakeSection()
            NotificationSection()
        }
        // Presentation is local state synced from the store rather than a
        // binding computed from it: SwiftUI writes `false` back on dismissal,
        // and a binding that forwarded that write to the store would let a
        // spurious dismissal throw away the news of a finished bake.
        .onChange(of: outcome?.id, initial: true) { _, id in
            isShowingOutcome = id != nil
        }
        .alert(
            outcome?.outcome == .completed ? "Your bake is ready" : "Your bake burned",
            isPresented: $isShowingOutcome,
            presenting: outcome
        ) { _ in
            Button("OK") {
                store.acknowledgeOutcome()
                // The news has been delivered in the app, so the banner it may
                // have arrived as has nothing left to say (spec 04).
                notifications.clearDeliveredCompletion()
            }
        } message: { session in
            Text(session.outcome == .completed
                 ? "\(RecipeCatalog.recipe(for: session.recipeID).name), \(session.durationMinutes) minutes."
                 : "You left the bakery mid-bake.")
        }
        .onChange(of: denialNotice, initial: true) { _, notice in
            isShowingDenialNotice = notice != nil
        }
        .alert(
            "Notifications are off",
            isPresented: $isShowingDenialNotice,
            presenting: denialNotice
        ) { _ in
            Button("OK") { notifications.acknowledgeDenialNotice() }
        } message: { notice in
            Text(notice)
        }
    }
}

/// The countdown is a *display*. It re-reads the store's resolution once a
/// second and counts nothing itself, so backgrounding, being killed and a clock
/// change all come out right for free (spec 03).
private struct BakeSection: View {
    @Environment(BakeryStore.self) private var store
    @Environment(BakeryNotifications.self) private var notifications
    @State private var isConfirmingCancel = false
    /// Written purely to invalidate the view each second. The value shown is
    /// always re-derived from the stored `endDate` on the next body pass.
    @State private var tick = 0

    var body: some View {
        Section("Session") {
            switch store.resolution {
            case .baking(let remaining):
                if let active = store.session.active {
                    LabeledContent("Baking", value: RecipeCatalog.recipe(for: active.recipeID).name)
                    LabeledContent("Remaining", value: Self.countdown(remaining))
                    LabeledContent("Ends", value: active.endDate.formatted(date: .omitted, time: .standard))
                }
                Button("Cancel bake", role: .destructive) { isConfirmingCancel = true }
            default:
                Text("No bake in flight")
                    .foregroundStyle(.secondary)
                Button("Bake a 1-minute cookie") { startBake(minutes: 1) }
                Button("Bake a 25-minute cookie") { startBake(minutes: 25) }
            }
        }
        .confirmationDialog(
            "Throw out this bake?",
            isPresented: $isConfirmingCancel,
            titleVisibility: .visible
        ) {
            Button("Burn it", role: .destructive) {
                store.finishActiveSession(as: .burned)
            }
            Button("Keep baking", role: .cancel) {}
        } message: {
            Text("You will not get the coins or the treat.")
        }
        .task {
            while !Task.isCancelled {
                store.resolveInFlightSession()
                tick &+= 1
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Permission is asked for here, in context, at the one moment its value is
    /// obvious — you have just committed to a bake and the alert is what tells
    /// you it is done (specs 04, 11). Never on cold launch, and the bake starts
    /// either way.
    private func startBake(minutes: Int) {
        Task {
            await notifications.requestAuthorizationForBake()
            store.startSession(recipeID: .chocolateChipCookie, durationMinutes: minutes)
        }
    }

    private static func countdown(_ remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// The by-hand surface for spec 04's device pass: what permission the app has,
/// the daily reminder and its time, and what is actually pending. Spec 13 owns
/// the real settings screen; this exists so the criteria can be checked on a
/// device before it does.
private struct NotificationSection: View {
    @Environment(BakeryStore.self) private var store
    @Environment(BakeryNotifications.self) private var notifications
    @State private var isReminderOn = false
    @State private var reminderTime = Date()
    @State private var pending: [String] = []

    private let settings = Settings()

    var body: some View {
        Section("Notifications") {
            LabeledContent("Permission", value: notifications.authorization.label)
            Toggle("Daily reminder", isOn: $isReminderOn)
            DatePicker(
                "Reminder time",
                selection: $reminderTime,
                displayedComponents: .hourAndMinute
            )

            if pending.isEmpty {
                Text("Nothing pending").foregroundStyle(.secondary)
            } else {
                ForEach(pending, id: \.self, content: Text.init)
            }
            Button("Refresh pending") { Task { await refreshPending() } }
        }
        .task {
            isReminderOn = settings.dailyReminderEnabled
            reminderTime = Self.date(from: settings.dailyReminderTime)
            await refreshPending()
        }
        // The reconcile that follows a bake starting or ending runs after this
        // section has already read its list, so a stale "nothing pending" would
        // be the one thing this surface must not say.
        .onChange(of: store.session) { _, _ in
            Task { await refreshPending() }
        }
        .onChange(of: isReminderOn) { _, isOn in
            settings.dailyReminderEnabled = isOn
            apply()
        }
        .onChange(of: reminderTime) { _, time in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            settings.dailyReminderTime = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            apply()
        }
    }

    private func apply() {
        notifications.reconcile(with: store)
        Task { await refreshPending() }
    }

    private func refreshPending() async {
        pending = await notifications.pendingIdentifiers().sorted()
    }

    private static func date(from time: TimeOfDay) -> Date {
        let now = Date()
        return Calendar.current.date(
            bySettingHour: time.hour, minute: time.minute, second: 0, of: now
        ) ?? now
    }
}

private extension UNAuthorizationStatus {
    var label: String {
        switch self {
        case .notDetermined: "not asked yet"
        case .denied: "denied"
        case .authorized: "allowed"
        case .provisional: "quiet delivery"
        case .ephemeral: "temporary"
        @unknown default: "unknown"
        }
    }
}
