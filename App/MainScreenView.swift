import SpriteKit
import SwiftUI

/// What the room offers at the bottom, from spec 06's state table.
enum MainScreenAction: Equatable {
    /// Nothing is baking: the "+" opens the recipe book (10).
    case start
    /// One bake is running, and the only way out of it is to throw it away —
    /// confirmed first (03).
    case stop
    /// The completion payoff is playing. The room is busy being celebrated in,
    /// and the "+" comes back once the baker has put the treat down (05).
    case none

    static func resolved(for resolution: SessionResolution, isCelebrating: Bool) -> MainScreenAction {
        switch resolution {
        case .baking:
            .stop
        // A bake whose end has passed but which has not been settled yet: the
        // payoff is one tick away, and offering a "+" in between would flash a
        // control the next frame takes back.
        case .completed:
            .none
        case .idle, .burned:
            isCelebrating ? .none : .start
        }
    }
}

/// The main screen (spec 06): a tray across the top, and the top-down room
/// filling everything below it.
///
/// This is the app-layer half of spec 05's boundary. It derives a
/// `BakeryScene.Model` from the store and pushes it down; the scene sends events
/// back up. Nothing else crosses — the scene never touches the store, and this
/// view never reaches into the scene's nodes.
///
/// SwiftUI owns everything around that: navigation, chrome, modals, `scenePhase`,
/// persistence and notification scheduling (00, 06).
struct MainScreenView: View {
    @Environment(BakeryStore.self) private var store
    @Environment(BakeryNotifications.self) private var notifications
    @Environment(BakeryFeedback.self) private var feedback
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
    @State private var isShowingDenialNotice = false
    /// Openable at launch for the same reason the book is: a case with a day's
    /// baking in it is a state no launch can otherwise reach, since filling it
    /// takes a day's worth of real timers.
    @State private var isShowingCase = ProcessInfo.processInfo.arguments.contains("-displayCase")
    @State private var isShowingSettings = ProcessInfo.processInfo.arguments.contains("-settings")
    /// Openable at launch so the modal can be screenshotted without tap
    /// tooling. `-recipeBookLocked` opens it on the first locked page instead,
    /// which is the other state worth a screenshot and the one no launch can
    /// otherwise reach.
    @State private var isShowingRecipeBook = ProcessInfo.processInfo.arguments
        .contains { $0 == "-recipeBook" || $0 == "-recipeBookLocked" }

    private let settings = Settings()

    var body: some View {
        // Read in the body pass, not only inside closures, so the @Observable
        // dependency is registered (the spec 03 lesson).
        let outcome = store.pendingOutcome
        let deliverOwed = watchedBakeWhileActive && outcome?.outcome == .completed
        let denialNotice = notifications.denialNotice

        GeometryReader { proxy in
            // Read out here, where they still exist: everything below ignores
            // the safe area, and insets measured from inside that come back as
            // zero — which is a tray with its readouts under the Dynamic Island.
            //
            // The size has to be put back together, though. This reader sits
            // *outside* the ignore, so it is proposed the safe area rather than
            // the screen, while the ZStack below then draws into the whole
            // thing from its top-left corner. Handing the short size down was a
            // room ending 96pt above the bottom of the phone with white under
            // it — the same trap as the insets, one layer along.
            let insets = proxy.safeAreaInsets
            let layout = ChromeLayout(
                size: CGSize(
                    width: proxy.size.width + insets.leading + insets.trailing,
                    height: proxy.size.height + insets.top + insets.bottom
                ),
                safeAreaTop: insets.top,
                safeAreaBottom: insets.bottom
            )
            ZStack {
                // No explicit isPaused: SKView already stops rendering while
                // the app is backgrounded, which is all spec 05's lifecycle
                // rule asks.
                SpriteView(scene: scene)
                    .frame(width: layout.scene.width, height: layout.scene.height)
                    // Inside that frame, so the overlay is handed the same size
                    // the scene is and both agree on where the room is.
                    .overlay { roomAccessibility }
                    .position(x: layout.scene.midX, y: layout.scene.midY)
                chrome(deliverOwed: deliverOwed, layout: layout)
                if isShowingRecipeBook {
                    recipeBook
                        .zIndex(1)
                        .transition(reduceMotion
                                    ? .opacity
                                    : .opacity.combined(with: .scale(scale: 1.04)))
                }
            }
            .ignoresSafeArea()
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
            // A bake resolved while the app was away still gets its moment
            // (12): this alert *is* the moment, since there is no walk to land
            // on, so the sound goes with it rather than being skipped as
            // something the user missed.
            if isShowingOutcome, let outcome { feedback.announce(outcome) }
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
        // Told once, and only ever after the user has started the bake the
        // alert was for (04). It arrives here rather than in settings because
        // this is where they were when permission was refused.
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
        .sheet(isPresented: $isShowingCase) {
            // Read here rather than captured when the tap arrived, so a bake
            // landing while the sheet is open shows up in it.
            DisplayCaseSheetView(day: store.today.displayCase) {
                isShowingCase = false
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheetView(
                authorization: notifications.authorization,
                // Both of these are the same shape: the sheet changes the
                // preference, and the app layer puts what is already running
                // back in line with it — the pending alerts (04), the hum (12).
                onSoundChanged: { feedback.settingsChanged() },
                onReminderChanged: { notifications.reconcile(with: store) },
                onDismiss: { isShowingSettings = false }
            )
        }
        .confirmationDialog(
            "Throw out this bake?",
            isPresented: $isConfirmingCancel,
            titleVisibility: .visible
        ) {
            Button("Burn it", role: .destructive) {
                // A deliberate burn reaches no alert — the user just confirmed
                // it — so this is the only place it can be felt (12).
                if let burned = store.finishActiveSession(as: .burned) {
                    feedback.announce(burned)
                }
            }
            Button("Keep baking", role: .cancel) {}
        } message: {
            Text("You will not get the coins or the treat.")
        }
    }

    /// The chrome: the tray across the top, and the one control floating near
    /// the bottom, both placed by `ChromeLayout` — the tray above the room
    /// entirely, the control clear of the door and the case (06).
    private func chrome(deliverOwed: Bool, layout: ChromeLayout) -> some View {
        ZStack {
            BakeryTrayView(
                layout: layout,
                coins: store.progress.wallet.coinBalance,
                streak: store.progress.streak.currentStreak,
                onSettings: { isShowingSettings = true }
            )

            BakeryActionButton(
                action: MainScreenAction.resolved(
                    for: store.resolution,
                    isCelebrating: deliverOwed
                ),
                onStart: { isShowingRecipeBook = true },
                onStop: { isConfirmingCancel = true }
            )
            .position(x: layout.action.midX, y: layout.action.midY)
        }
    }

    /// The room as VoiceOver sees it (spec 13).
    ///
    /// Almost nothing on this screen is a native control: the oven, the baker
    /// and the case are `SKNode`s and the countdown is bitmap sprites, so
    /// without this the main screen is a tray and one button over an empty
    /// rectangle. Three elements, which is what the criteria name — the oven
    /// carries the remaining time, the baker carries what it is doing, and the
    /// case carries today's contents and the way into the sheet.
    ///
    /// Every frame is grown to clear the minimum target first: a fixture that
    /// spans one tile is 32pt, and a VoiceOver element too small to land on is
    /// the same problem as a tap target too small to hit.
    ///
    /// Hit testing stays off so the scene keeps the actual tap and remains the
    /// single path to `.caseTapped`.
    private var roomAccessibility: some View {
        GeometryReader { proxy in
            let layout = RoomLayout(fitting: proxy.size)
            let plan = RoomPlan(fitting: layout)
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let phase = model.phase
            let caseFrame = reachable(plan.caseRegion(in: layout), in: layout, within: bounds)

            ZStack {
                readout(
                    reachable(plan.ovenRegion(in: layout), in: layout, within: bounds),
                    label: "Oven",
                    value: RoomNarration.oven(phase)
                )
                readout(
                    reachable(
                        plan.bakerRegion(standingOn: bakerTile(for: phase, in: plan), in: layout),
                        in: layout,
                        within: bounds
                    ),
                    label: "Baker",
                    value: RoomNarration.baker(phase)
                )
                Color.clear
                    .frame(width: caseFrame.width, height: caseFrame.height)
                    .accessibilityElement()
                    .accessibilityLabel("Display case")
                    .accessibilityValue(
                        RoomNarration.displayCase(count: store.today.displayCase.totalCount)
                    )
                    .accessibilityHint("Lists today's bakes")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { isShowingCase = true }
                    .position(x: caseFrame.midX, y: caseFrame.midY)
            }
        }
        .allowsHitTesting(false)
    }

    /// A room region in the view's coordinates, big enough to land on.
    private func reachable(
        _ region: CGRect,
        in layout: RoomLayout,
        within bounds: CGRect
    ) -> CGRect {
        layout.inViewSpace(region).grown(toAtLeast: ChromeLayout.minimumTarget, within: bounds)
    }

    /// Labelled before it is placed: `position` fills the space it is given, and
    /// an element built the other way round would claim the whole room.
    private func readout(_ frame: CGRect, label: String, value: String) -> some View {
        Color.clear
            .frame(width: frame.width, height: frame.height)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .position(x: frame.midX, y: frame.midY)
    }

    /// Which fixture the baker is at, from the phase alone. The scene's own
    /// anchors are keyed by *activity* and include the walk between them (05);
    /// this only needs where the walk ends, which the phase already says.
    private func bakerTile(for phase: BakeryScene.Model.Phase, in plan: RoomPlan) -> RoomTile {
        switch phase {
        case .idle: plan.restTile
        case .baking: plan.stationTile
        case .delivering: plan.deliverTile
        }
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
            onPurchase: { recipeID in
                if store.purchase(recipeID) == .bought { feedback.play(.purchase) }
            },
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
            // The end of the walk, not the timer reaching zero. Spec 12 is
            // explicit that the ding lands with the treat: firing it three
            // seconds earlier, while the baker is still carrying it, is the
            // mismatch that reads as broken.
            if let outcome = store.pendingOutcome { feedback.announce(outcome) }
        case .deliveryFinished:
            // The walk was the celebration, so the outcome is spent: no alert,
            // and the banner it may have arrived as has nothing left to say.
            watchedBakeWhileActive = false
            store.acknowledgeOutcome()
            notifications.clearDeliveredCompletion()
            sync()
        case .caseTapped:
            isShowingCase = true
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
