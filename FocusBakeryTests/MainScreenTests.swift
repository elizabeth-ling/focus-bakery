import CoreGraphics
import Testing
@testable import FocusBakery

/// Spec 06's state table and its text-tier rule, which are the two parts of the
/// shell that can be judged without a screenshot.
@MainActor
@Suite("Main screen")
struct MainScreenTests {
    private static let phones: [(name: String, size: CGSize, top: CGFloat, bottom: CGFloat)] = [
        ("iPhone SE (2nd/3rd gen)", CGSize(width: 375, height: 667), 20, 0),
        ("iPhone 13 mini", CGSize(width: 375, height: 812), 50, 34),
        ("iPhone 16", CGSize(width: 393, height: 852), 62, 34),
        ("iPhone 16 Pro Max", CGSize(width: 440, height: 956), 62, 34),
    ]

    @Test("The + is offered only when a bake could actually start")
    func theActionFollowsTheStateTable() {
        // Fresh day, and a day with treats already in the case: both are "no
        // session", and both offer the "+".
        #expect(MainScreenAction.resolved(for: .idle, isCelebrating: false) == .start)
        // One session at a time (02): mid-bake the "+" is replaced, not
        // disabled in place, so it cannot be tapped into failing.
        #expect(MainScreenAction.resolved(for: .baking(remaining: 300), isCelebrating: false) == .stop)
        #expect(MainScreenAction.resolved(for: .baking(remaining: 1), isCelebrating: false) == .stop)
        // The payoff is playing: nothing is offered until the baker has put the
        // treat down.
        #expect(MainScreenAction.resolved(for: .idle, isCelebrating: true) == .none)
        // A bake that has ended but has not been settled yet is a tick away
        // from that payoff, so it offers nothing either.
        #expect(MainScreenAction.resolved(for: .completed, isCelebrating: false) == .none)
        // A burn adds nothing and celebrates nothing (05): straight back to
        // being able to start again.
        #expect(MainScreenAction.resolved(for: .burned, isCelebrating: false) == .start)
    }

    /// Spec 06's gotcha, made checkable: chrome floats over the room now, so a
    /// TTF label can drift next to bitmap digits "at a screen size nobody
    /// checked". Every supported size is checked, with a whole tile of room
    /// demanded between the tiers rather than merely no overlap.
    @Test("The two text tiers stay a tile apart on every supported iPhone")
    func textTiersStayApart() {
        for phone in Self.phones {
            let scene = BakeryScene(size: phone.size)
            scene.scaleMode = .resizeFill
            // The busiest the room's own text ever gets: a countdown, its tag,
            // and quantity counts on the shelf.
            scene.apply(BakeryScene.Model(
                phase: .baking(secondsRemaining: 1_499),
                treats: [.chocolateChipCookie, .chocolateChipCookie, .croissant, .cake, .cake]
            ))

            let layout = RoomLayout(fitting: phone.size)
            let chrome = ChromeLayout(
                size: phone.size,
                safeAreaTop: phone.top,
                safeAreaBottom: phone.bottom
            )
            let clearance = layout.tileSize
            let bar = chrome.bar.insetBy(dx: -clearance, dy: -clearance)
            let action = chrome.action.insetBy(dx: -clearance, dy: -clearance)

            #expect(!scene.bitmapTextFrames.isEmpty, "\(phone.name): the room drew no text to check")
            for text in scene.bitmapTextFrames.map({ layout.inViewSpace($0) }) {
                #expect(!bar.intersects(text),
                        "\(phone.name): bitmap text \(text) crowds the chrome bar \(chrome.bar)")
                #expect(!action.intersects(text),
                        "\(phone.name): bitmap text \(text) crowds the action \(chrome.action)")
            }
        }
    }

    /// The coin balance is chrome now, not in-scene bitmap text, so that it can
    /// sit inside the safe area and be read by VoiceOver (06, 13). The room
    /// must not have kept a second copy.
    @Test("The room draws no coin count of its own")
    func theRoomLeavesCoinsToTheChrome() {
        let scene = BakeryScene(size: CGSize(width: 393, height: 852))
        scene.scaleMode = .resizeFill
        scene.apply(BakeryScene.Model(phase: .idle))
        #expect(scene.bitmapTextFrames.isEmpty)
    }
}
