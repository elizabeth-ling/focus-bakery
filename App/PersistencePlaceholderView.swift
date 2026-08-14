import SwiftUI

/// Temporary. Spec 06 replaces this with the bakery room; until then it exists
/// so persistence and the timer can be exercised by hand on a device — start a
/// bake, leave, come back late, kill the app, and check what survived.
struct PersistencePlaceholderView: View {
    @Environment(BakeryStore.self) private var store

    var body: some View {
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
        }
        .alert(
            store.pendingOutcome?.outcome == .completed ? "Your bake is ready" : "Your bake burned",
            isPresented: Binding(
                get: { store.pendingOutcome != nil },
                set: { if !$0 { store.acknowledgeOutcome() } }
            )
        ) {
            Button("OK") { store.acknowledgeOutcome() }
        } message: {
            if let outcome = store.pendingOutcome {
                Text(outcome.outcome == .completed
                     ? "\(RecipeCatalog.recipe(for: outcome.recipeID).name), \(outcome.durationMinutes) minutes."
                     : "You left the bakery mid-bake.")
            }
        }
    }
}

/// The countdown is a *display*. It re-reads the store's resolution once a
/// second and counts nothing itself, so backgrounding, being killed and a clock
/// change all come out right for free (spec 03).
private struct BakeSection: View {
    @Environment(BakeryStore.self) private var store
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
                Button("Bake a 1-minute cookie") {
                    store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 1)
                }
                Button("Bake a 25-minute cookie") {
                    store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 25)
                }
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

    private static func countdown(_ remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
