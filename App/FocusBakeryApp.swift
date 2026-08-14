import SwiftUI

@main
struct FocusBakeryApp: App {
    @State private var store = BakeryStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ChromeFont.register()
    }

    var body: some Scene {
        WindowGroup {
            root
                .environment(store)
                .task { openBakery() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                openBakery()
            case .background:
                store.noteLeftForeground()
            // `.inactive` is an incoming call, Control Centre, the app switcher
            // or a Face ID sheet. The user is still here, so it never starts the
            // burn grace (spec 03).
            default:
                break
            }
        }
    }

    /// Spec 01's screenshot criterion has to judge the scene full-bleed, with no
    /// system chrome beside its bitmap text, so the proof surface is selected at
    /// launch rather than navigated to — both scaffolds stay reachable and
    /// neither has to host the other:
    ///
    ///     xcrun simctl launch <device> com.focusbakery.FocusBakery -pixelProof
    ///
    /// Temporary, with `PixelProofView` and `PersistencePlaceholderView` both.
    @ViewBuilder
    private var root: some View {
        if ProcessInfo.processInfo.arguments.contains("-pixelProof") {
            PixelProofView()
        } else {
            PersistencePlaceholderView()
        }
    }

    private func openBakery() {
        // The day key is re-derived here, not cached at launch: the timezone may
        // have changed while the app was backgrounded.
        store.refreshForCurrentDay()
        // A bake may have finished — or burned — while the app was suspended.
        store.resolveInFlightSession()
        store.markBakeryOpened()
    }
}
