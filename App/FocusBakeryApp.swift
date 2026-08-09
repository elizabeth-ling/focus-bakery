import SwiftUI

@main
struct FocusBakeryApp: App {
    @State private var store = BakeryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PersistencePlaceholderView()
                .environment(store)
                .task { openBakery() }
        }
        .onChange(of: scenePhase) { _, phase in
            // The day key is re-derived here, not cached at launch: the
            // timezone may have changed while the app was backgrounded.
            guard phase == .active else { return }
            openBakery()
        }
    }

    private func openBakery() {
        store.refreshForCurrentDay()
        store.markBakeryOpened()
    }
}
