import SwiftUI

/// Temporary. Spec 06 replaces this with the bakery room; until then it exists
/// so persistence can be exercised by hand on a device — kill the app, relaunch,
/// and check the numbers survived.
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

            Section("Session") {
                if let active = store.session.active {
                    LabeledContent("In flight", value: RecipeCatalog.recipe(for: active.recipeID).name)
                    LabeledContent("Ends", value: active.endDate.formatted(date: .omitted, time: .standard))
                } else {
                    Text("No bake in flight")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Bake a 1-minute cookie") {
                    store.startSession(recipeID: .chocolateChipCookie, durationMinutes: 1)
                }
                .disabled(store.session.active != nil)

                Button("Finish it") {
                    store.finishActiveSession(as: .completed)
                }
                .disabled(store.session.active == nil)
            }
        }
    }
}
