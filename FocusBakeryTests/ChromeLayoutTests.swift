import CoreGraphics
import Testing
@testable import FocusBakery

/// Spec 06's "chrome never obscures the room" criterion, checked as geometry
/// rather than by eye — the same way spec 08 checks the case never spills.
///
/// Every device in the supported span (01) with the safe area it actually has:
/// the SE has a status bar and no home indicator, everything since has both, and
/// the two ends are what a top strip and a bottom control would get wrong.
///
/// The tray makes the obscuring criterion structural — it sits above the room
/// rather than over it — so the weight here shifts to what the tray costs: the
/// room has to survive on what is left of the screen, at the same scale, on
/// every one of these.
@Suite("Chrome layout")
struct ChromeLayoutTests {
    private struct Phone {
        let name: String
        let size: CGSize
        let safeAreaTop: CGFloat
        let safeAreaBottom: CGFloat

        var chrome: ChromeLayout {
            ChromeLayout(size: size, safeAreaTop: safeAreaTop, safeAreaBottom: safeAreaBottom)
        }

        /// The room is laid out in what the tray leaves, not in the whole screen.
        var layout: RoomLayout { RoomLayout(fitting: chrome.scene.size) }
        var plan: RoomPlan { RoomPlan(fitting: layout) }
    }

    private static let phones = [
        Phone(name: "iPhone SE (2nd/3rd gen)", size: CGSize(width: 375, height: 667),
              safeAreaTop: 20, safeAreaBottom: 0),
        Phone(name: "iPhone 13 mini", size: CGSize(width: 375, height: 812),
              safeAreaTop: 50, safeAreaBottom: 34),
        Phone(name: "iPhone 16", size: CGSize(width: 393, height: 852),
              safeAreaTop: 62, safeAreaBottom: 34),
        Phone(name: "iPhone 16 Pro", size: CGSize(width: 402, height: 874),
              safeAreaTop: 62, safeAreaBottom: 34),
        Phone(name: "iPhone 16 Pro Max", size: CGSize(width: 440, height: 956),
              safeAreaTop: 62, safeAreaBottom: 34),
    ]

    /// What the criterion names, plus the two the room would look broken
    /// without: the door the "+" floats above, and the baker standing idle in
    /// front of house waiting to be given something to do.
    ///
    /// In screen coordinates, because that is where the chrome is: the room's
    /// own coordinates now start below the tray rather than at the screen's top.
    private func fixtures(of phone: Phone) -> [(String, CGRect)] {
        let layout = phone.layout
        let plan = phone.plan
        let scene = phone.chrome.scene
        let restingBaker = CGRect(
            origin: layout.tileRect(column: plan.restTile.column, row: plan.restTile.row).origin,
            size: CGSize(width: layout.tileSize, height: layout.tileSize * 2)
        )
        return [
            ("the oven", plan.ovenRegion(in: layout)),
            ("the station", plan.stationRegion(in: layout)),
            ("the display case", plan.caseRegion(in: layout)),
            ("the door", layout.tileRect(column: plan.doorTile.column, row: plan.doorTile.row)),
            ("the resting baker", restingBaker),
        ].map { ($0.0, layout.inViewSpace($0.1).offsetBy(dx: scene.minX, dy: scene.minY)) }
    }

    @Test("Chrome covers none of the room's fixtures on any supported iPhone")
    func chromeClearsTheFixtures() {
        for phone in Self.phones {
            let chrome = phone.chrome
            for (fixture, region) in fixtures(of: phone) {
                #expect(!chrome.tray.intersects(region),
                        "\(phone.name): the tray \(chrome.tray) covers \(fixture) \(region)")
                #expect(!chrome.action.intersects(region),
                        "\(phone.name): the action \(chrome.action) covers \(fixture) \(region)")
            }
        }
    }

    /// The structural half of the criterion above: the tray does not clear the
    /// fixtures by being placed carefully, it clears them because the room
    /// begins where the tray ends. Everything in the room inherits that.
    @Test("The tray and the room share an edge and nothing else")
    func theTrayHandsTheRoomTheRest() {
        for phone in Self.phones {
            let chrome = phone.chrome
            #expect(chrome.tray.minX == 0, "\(phone.name): the tray does not reach the leading edge")
            #expect(chrome.tray.width == phone.size.width,
                    "\(phone.name): the tray does not span the screen")
            #expect(chrome.tray.maxY == chrome.scene.minY, "\(phone.name): tray and room disagree")
            #expect(!chrome.tray.intersects(chrome.scene), "\(phone.name)")
            #expect(chrome.scene.maxY == phone.size.height,
                    "\(phone.name): the room stops short of the bottom")
        }
    }

    /// The tray's cost. It takes real height off the screen, and the room has to
    /// keep being a bakery with a back and a front of house on what is left —
    /// at the same magnification, or a chrome pixel and a room pixel stop being
    /// the same physical size (01).
    @Test("The room still seats itself under the tray, at the same scale")
    func theRoomSurvivesTheTray() {
        for phone in Self.phones {
            let layout = phone.layout
            #expect(layout.scale == PixelGrid.chromeScale,
                    "\(phone.name): the room resolved ×\(layout.scale) under the tray")
            #expect(layout.columns >= PixelGrid.smallestUsefulRoom.columns, "\(phone.name)")
            #expect(layout.rows >= PixelGrid.smallestUsefulRoom.rows, "\(phone.name)")
        }
    }

    @Test("Both slots sit on screen, inside the safe area")
    func chromeStaysWithinTheSafeArea() {
        for phone in Self.phones {
            let chrome = phone.chrome
            for (slot, rect) in [("readouts", chrome.content), ("action", chrome.action)] {
                #expect(rect.minX >= 0, "\(phone.name): \(slot) starts off screen")
                #expect(rect.maxX <= phone.size.width, "\(phone.name): \(slot) runs off screen")
                #expect(rect.minY >= phone.safeAreaTop,
                        "\(phone.name): \(slot) is under the status bar")
                #expect(rect.maxY <= phone.size.height - phone.safeAreaBottom,
                        "\(phone.name): \(slot) is under the home indicator")
            }
            // The tray's material is meant to run up *through* the safe area —
            // it is the one thing here that may, and a strip of nothing above it
            // is what happens if it stops.
            #expect(chrome.tray.minY == 0, "\(phone.name): the tray leaves a gap above it")
            #expect(chrome.content.maxY <= chrome.tray.maxY,
                    "\(phone.name): the readouts hang off the tray")
        }
    }

    /// Spec 13's floor. The readout row has to hold the settings entry, and the
    /// action is the app's primary control.
    @Test("Both slots clear the minimum tap target")
    func slotsAreBigEnoughToTap() {
        for phone in Self.phones {
            let chrome = phone.chrome
            #expect(chrome.content.height >= ChromeLayout.minimumTarget, "\(phone.name)")
            #expect(chrome.content.width >= ChromeLayout.minimumTarget * 3, "\(phone.name)")
            #expect(chrome.action.width >= ChromeLayout.minimumTarget, "\(phone.name)")
            #expect(chrome.action.height >= ChromeLayout.minimumTarget, "\(phone.name)")
        }
    }

    /// Rule 3 (01): the action carries authored pixel art, so its origin has to
    /// land on a whole art pixel or the plate's outline straddles one. The tray
    /// is what makes this worth re-checking — the control is snapped in the
    /// room's coordinates and then moved down by the tray's depth, so a tray
    /// that is not itself a whole number of pixels deep would knock it off.
    @Test("The action lands on the art-pixel grid")
    func actionSitsOnTheGrid() {
        for phone in Self.phones {
            let step = CGFloat(phone.layout.scale)
            let chrome = phone.chrome
            #expect(chrome.tray.height.truncatingRemainder(dividingBy: step) == 0, "\(phone.name)")
            #expect(chrome.action.minX.truncatingRemainder(dividingBy: step) == 0, "\(phone.name)")
            #expect(chrome.action.minY.truncatingRemainder(dividingBy: step) == 0, "\(phone.name)")
            #expect(chrome.action.width.truncatingRemainder(dividingBy: step) == 0, "\(phone.name)")
        }
    }

    /// A safe-area inset is a system number, not one of ours, so it is the one
    /// input here that could arrive off the grid. The tray absorbs it rather
    /// than passing it on to the room.
    @Test("An odd safe area still leaves the room on the grid")
    func oddSafeAreasAreAbsorbedByTheTray() {
        for top in [CGFloat(0), 1, 20, 47, 62.5] {
            let chrome = ChromeLayout(
                size: CGSize(width: 393, height: 852),
                safeAreaTop: top,
                safeAreaBottom: 34
            )
            let step = CGFloat(PixelGrid.chromeScale)
            #expect(chrome.scene.minY.truncatingRemainder(dividingBy: step) == 0, "top \(top)")
            #expect(chrome.content.minY >= top, "top \(top): the readouts sit under the status bar")
        }
    }

    /// The recipe book's way out moved off the page and onto the screen (10),
    /// which is only an improvement if the band it moved into is really empty:
    /// below the tray, above the page, and wide enough to be tapped. The page is
    /// authored art at a fixed size, so "the book still fits underneath" is a
    /// measurement the smallest phone can fail.
    @Test("The modal's close control clears both the tray and the page")
    func theCloseControlHasABandOfItsOwn() {
        for phone in Self.phones {
            let chrome = phone.chrome
            let close = chrome.modalClose
            let stage = chrome.modalStage

            #expect(close.width >= ChromeLayout.minimumTarget, "\(phone.name)")
            #expect(close.height >= ChromeLayout.minimumTarget, "\(phone.name)")
            #expect(close.minY >= chrome.trayEdge.maxY,
                    "\(phone.name): the close control is under the tray's shadow")
            #expect(close.maxX <= phone.size.width, "\(phone.name): the close control runs off screen")
            #expect(close.maxY <= phone.size.height - phone.safeAreaBottom, "\(phone.name)")
            #expect(!close.intersects(stage), "\(phone.name): the close control sits on the modal")

            // Where `RecipeBookModalView` puts the page: centred in the stage.
            let size = RecipeBookModalView.pageSize
            let page = CGRect(
                x: stage.midX - size.width / 2,
                y: stage.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
            #expect(stage.contains(page),
                    "\(phone.name): the \(size) page does not fit the stage \(stage)")
            #expect(!close.intersects(page),
                    "\(phone.name): the close control \(close) covers the page \(page)")
        }
    }

    /// Spec 13's tray, as the shape it is: a side bar, not a bottom sheet. The
    /// height claim is the whole viewport including both safe areas — it draws
    /// its own margins — and the width claim is "most of it, and not all", since
    /// a tray that reached both edges would be a screen rather than a drawer
    /// over the room. It hangs off the leading edge, the end the gear is on.
    @Test("The settings tray is a full-height side bar over most of the width")
    func theSettingsTrayIsASideBar() {
        for phone in Self.phones {
            let tray = phone.chrome.settingsTray
            #expect(tray.minY == 0, "\(phone.name): the tray stops below the top of the screen")
            #expect(tray.height == phone.size.height,
                    "\(phone.name): the tray does not span the viewport")
            #expect(tray.minX == 0, "\(phone.name): the tray is off the leading edge")
            #expect(tray.width > phone.size.width / 2,
                    "\(phone.name): the tray is not most of the width")
            #expect(tray.maxX < phone.size.width,
                    "\(phone.name): the tray leaves no room showing beside it")
            #expect(tray.width.truncatingRemainder(dividingBy: CGFloat(PixelGrid.chromeScale)) == 0,
                    "\(phone.name): the tray's edge lands mid-pixel")
        }
    }

    @Test("A scene too small to seat a room still resolves usable chrome")
    func degenerateScenesStillResolve() {
        let chrome = ChromeLayout(size: CGSize(width: 200, height: 300), safeAreaTop: 20, safeAreaBottom: 0)
        #expect(chrome.content.width >= 0)
        #expect(chrome.scene.height > 0)
        #expect(chrome.action.width > 0)
    }
}
