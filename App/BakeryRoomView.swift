import SpriteKit
import SwiftUI

/// Hosts the bakery room against the real store, launched with `-bakeryRoom`.
/// Temporary in the same sense as `PersistencePlaceholderView`: spec 06 builds
/// the real shell around the scene; until then this is the surface spec 05's
/// loop is validated on.
///
/// The spec's boundary lives here. This view derives a `BakeryScene.Model`
/// from the store and pushes it down; the scene sends events back up. Nothing
/// else crosses — the scene never touches the store, and this view never
/// reaches into the scene's nodes.
struct BakeryRoomView: View {
    @Environment(BakeryStore.self) private var store
    @Environment(BakeryNotifications.self) private var notifications
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Held rather than computed in `body`: a fresh scene per layout pass
    /// would restart every animation on every redraw.
    @State private var scene: BakeryScene = {
        let scene = BakeryScene()
        scene.scaleMode = .resizeFill
        return scene
    }()

    /// Whether this foreground stint watched the bake run. Only a completion
    /// the user saw coming earns the deliver walk; one that resolved while the
    /// app was in the background arrives with the treat already in the case
    /// and the news broken by alert instead (specs 05, 06).
    @State private var watchedBakeWhileActive = false
    @State private var isConfirmingCancel = false
    @State private var isShowingOutcome = false

    var body: some View {
        // Read in the body pass, not only inside closures, so the @Observable
        // dependency is registered (the spec 03 lesson).
        let outcome = store.pendingOutcome
        let deliverOwed = watchedBakeWhileActive && outcome?.outcome == .completed

        ZStack(alignment: .bottom) {
            SpriteView(scene: scene, isPaused: scenePhase != .active)
                .ignoresSafeArea()
            controls
        }
        .task {
            scene.onEvent = { handle($0) }
            // The display tick: re-reads the store each second and re-derives
            // the model. Nothing here counts time (spec 03).
            while !Task.isCancelled {
                store.resolveInFlightSession()
                sync()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: store.session) { _, _ in sync() }
        .onChange(of: scenePhase) { _, phase in
            // Reset on .background only: .inactive is a call or Control
            // Centre — the user is still here and still owed the walk.
            if phase == .background { watchedBakeWhileActive = false }
            sync()
        }
        .onChange(of: reduceMotion) { _, _ in sync() }
        .onChange(of: outcome?.id, initial: true) { _, id in
            isShowingOutcome = id != nil && !deliverOwed
        }
        .alert(
            outcome?.outcome == .completed ? "Your bake is ready" : "Your bake burned",
            isPresented: $isShowingOutcome,
            presenting: outcome
        ) { _ in
            Button("OK") {
                store.acknowledgeOutcome()
                notifications.clearDeliveredCompletion()
                sync()
            }
        } message: { session in
            Text(session.outcome == .completed
                 ? "\(RecipeCatalog.recipe(for: session.recipeID).name), waiting in the case."
                 : "You left the bakery mid-bake.")
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
    }

    /// Scaffold controls until spec 06 brings the "+" button and spec 10 the
    /// recipe book. SwiftUI chrome, physically apart from the bitmap text (01).
    private var controls: some View {
        HStack(spacing: 12) {
            switch store.resolution {
            case .baking:
                Button("Cancel bake", role: .destructive) { isConfirmingCancel = true }
            default:
                Button("Bake 1 min") { start(minutes: 1) }
                Button("Bake 25 min") { start(minutes: 25) }
            }
        }
        .buttonStyle(.borderedProminent)
        .padding(.bottom, 20)
    }

    /// App state → scene model, the one place the translation happens.
    private var model: BakeryScene.Model {
        let phase: BakeryScene.Model.Phase
        if case .baking(let remaining) = store.resolution {
            phase = .baking(secondsRemaining: max(0, Int(remaining.rounded(.up))))
        } else if let outcome = store.pendingOutcome,
                  outcome.outcome == .completed,
                  watchedBakeWhileActive {
            phase = .delivering(outcome.recipeID)
        } else {
            phase = .idle
        }
        return BakeryScene.Model(
            phase: phase,
            treats: store.today.displayCase.treats,
            coins: store.progress.wallet.coinBalance,
            reduceMotion: reduceMotion
        )
    }

    private func sync() {
        if scenePhase == .active, case .baking = store.resolution {
            watchedBakeWhileActive = true
        }
        scene.apply(model)
    }

    private func handle(_ event: BakeryScene.Event) {
        switch event {
        case .treatPlaced:
            break
        case .deliveryFinished:
            // The walk was the celebration, so the outcome is spent: no alert,
            // and the banner it may have arrived as has nothing left to say.
            watchedBakeWhileActive = false
            store.acknowledgeOutcome()
            notifications.clearDeliveredCompletion()
            sync()
        case .caseTapped:
            // Spec 08 presents today's bakes here.
            break
        }
    }

    /// Permission is asked in context, at the moment its value is obvious
    /// (specs 04, 11). The bake starts either way.
    private func start(minutes: Int) {
        Task {
            // A payoff still pending when a new bake starts was superseded, not
            // lost — the treat is in the case either way.
            store.acknowledgeOutcome()
            await notifications.requestAuthorizationForBake()
            store.startSession(recipeID: RecipeCatalog.starter, durationMinutes: minutes)
        }
    }
}
