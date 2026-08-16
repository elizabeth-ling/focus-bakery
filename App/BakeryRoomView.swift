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
    /// Openable at launch so the modal can be screenshotted without tap
    /// tooling, the same way `-pixelProof` serves spec 01. `-recipeBookLocked`
    /// opens it on the first locked page instead, which is the other state
    /// worth a screenshot and the one no launch can otherwise reach.
    @State private var isShowingRecipeBook = ProcessInfo.processInfo.arguments
        .contains { $0 == "-recipeBook" || $0 == "-recipeBookLocked" }

    private let settings = Settings()

    var body: some View {
        // Read in the body pass, not only inside closures, so the @Observable
        // dependency is registered (the spec 03 lesson).
        let outcome = store.pendingOutcome
        let deliverOwed = watchedBakeWhileActive && outcome?.outcome == .completed

        ZStack(alignment: .bottom) {
            // No explicit isPaused: SKView already stops rendering while the
            // app is backgrounded, which is all spec 05's lifecycle rule asks.
            SpriteView(scene: scene)
                .ignoresSafeArea()
            if !isShowingRecipeBook {
                controls
            }
            if isShowingRecipeBook {
                recipeBook
                    .zIndex(1)
                    .transition(reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 1.04)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: isShowingRecipeBook)
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

    /// Scaffold controls until spec 06 brings the real "+" chrome. SwiftUI,
    /// physically apart from the bitmap text (01). The "+" only exists while
    /// nothing is baking, which is how the modal cannot be opened mid-session
    /// (specs 06, 10).
    private var controls: some View {
        HStack(spacing: 12) {
            switch store.resolution {
            case .baking:
                Button("Cancel bake", role: .destructive) { isConfirmingCancel = true }
            default:
                Button("+") { isShowingRecipeBook = true }
                    .font(ChromeFont.pixel(3))
                    .accessibilityLabel("Start a bake")
            }
        }
        .buttonStyle(.borderedProminent)
        .padding(.bottom, 20)
    }

    /// Spec 10's modal, fed and drained here so the boundary stays the same as
    /// the scene's: the book reads the store through this view and hands back
    /// one event.
    private var recipeBook: some View {
        // Read in the body pass so the page re-prices itself the moment a
        // purchase lands, which is what turns the bought page startable in
        // place (the spec 03 lesson).
        let book = store.recipeBook
        return RecipeBookModalView(
            entries: book,
            coinBalance: store.progress.wallet.coinBalance,
            initialRecipeID: openingPage(of: book),
            initialMinutes: settings.lastBakeDurationMinutes,
            onStart: { recipeID, minutes in
                isShowingRecipeBook = false
                start(recipeID: recipeID, minutes: minutes)
            },
            onPurchase: { store.purchase($0) },
            onDismiss: { isShowingRecipeBook = false }
        )
    }

    /// The book opens on what the user last baked (spec 10), or on the starter
    /// before there is one — and on the first locked page under the screenshot
    /// flag, which is the only way to reach that state without tap tooling.
    private func openingPage(of book: [RecipeBookEntry]) -> RecipeID {
        if ProcessInfo.processInfo.arguments.contains("-recipeBookLocked"),
           let locked = book.first(where: { !$0.isUnlocked }) {
            return locked.id
        }
        return settings.lastBakeRecipeID.flatMap { store.isUnlocked($0) ? $0 : nil }
            ?? RecipeCatalog.starter
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
    private func start(recipeID: RecipeID, minutes: Int) {
        // Remembered at start, not at completion: what the book should open
        // showing next time is what the user last chose (spec 10).
        settings.lastBakeRecipeID = recipeID
        settings.lastBakeDurationMinutes = minutes
        Task {
            // A payoff still pending when a new bake starts was superseded, not
            // lost — the treat is in the case either way.
            store.acknowledgeOutcome()
            await notifications.requestAuthorizationForBake()
            store.startSession(recipeID: recipeID, durationMinutes: minutes)
        }
    }
}
