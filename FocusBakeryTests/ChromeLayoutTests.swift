import CoreGraphics
import Testing
@testable import FocusBakery

/// Spec 06's "chrome never obscures the room" criterion, checked as geometry
/// rather than by eye — the same way spec 08 checks the case never spills.
///
/// Every device in the supported span (01) with the safe area it actually has:
/// the SE has a status bar and no home indicator, everything since has both, and
/// the two ends are what a chrome bar pinned to the top would get wrong.
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

        var layout: RoomLayout { RoomLayout(fitting: size) }
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
    private func fixtures(of phone: Phone) -> [(String, CGRect)] {
        let layout = phone.layout
        let plan = phone.plan
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
        ].map { ($0.0, layout.inViewSpace($0.1)) }
    }

    @Test("Chrome covers none of the room's fixtures on any supported iPhone")
    func chromeClearsTheFixtures() {
        for phone in Self.phones {
            let chrome = phone.chrome
            for (fixture, region) in fixtures(of: phone) {
                #expect(!chrome.bar.intersects(region),
                        "\(phone.name): the bar \(chrome.bar) covers \(fixture) \(region)")
                #expect(!chrome.action.intersects(region),
                        "\(phone.name): the action \(chrome.action) covers \(fixture) \(region)")
            }
        }
    }

    @Test("Both slots sit on screen, inside the safe area")
    func chromeStaysWithinTheSafeArea() {
        for phone in Self.phones {
            let chrome = phone.chrome
            for (slot, rect) in [("bar", chrome.bar), ("action", chrome.action)] {
                #expect(rect.minX >= 0, "\(phone.name): \(slot) starts off screen")
                #expect(rect.maxX <= phone.size.width, "\(phone.name): \(slot) runs off screen")
                #expect(rect.minY >= phone.safeAreaTop,
                        "\(phone.name): \(slot) is under the status bar")
                #expect(rect.maxY <= phone.size.height - phone.safeAreaBottom,
                        "\(phone.name): \(slot) is under the home indicator")
            }
        }
    }

    /// Spec 13's floor. The bar has to hold the settings entry, and the action
    /// is the app's primary control.
    @Test("Both slots clear the minimum tap target")
    func slotsAreBigEnoughToTap() {
        for phone in Self.phones {
            let chrome = phone.chrome
            #expect(chrome.bar.height >= ChromeLayout.minimumTarget, "\(phone.name)")
            #expect(chrome.bar.width >= ChromeLayout.minimumTarget * 3, "\(phone.name)")
            #expect(chrome.action.width >= ChromeLayout.minimumTarget, "\(phone.name)")
            #expect(chrome.action.height >= ChromeLayout.minimumTarget, "\(phone.name)")
        }
    }

    /// Rule 3 (01): the action carries authored pixel art, so its origin has to
    /// land on a whole art pixel or the plate's outline straddles one.
    @Test("The action lands on the art-pixel grid")
    func actionSitsOnTheGrid() {
        for phone in Self.phones {
            let step = CGFloat(phone.layout.scale)
            let chrome = phone.chrome
            #expect(chrome.action.minX.truncatingRemainder(dividingBy: step) == 0, "\(phone.name)")
            #expect(chrome.action.minY.truncatingRemainder(dividingBy: step) == 0, "\(phone.name)")
            #expect(chrome.action.width.truncatingRemainder(dividingBy: step) == 0, "\(phone.name)")
        }
    }

    @Test("A scene too small to seat a room still resolves usable chrome")
    func degenerateScenesStillResolve() {
        let chrome = ChromeLayout(size: CGSize(width: 200, height: 300), safeAreaTop: 20, safeAreaBottom: 0)
        #expect(chrome.bar.width >= 0)
        #expect(chrome.action.width > 0)
    }
}
