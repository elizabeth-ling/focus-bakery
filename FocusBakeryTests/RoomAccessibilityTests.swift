import CoreGraphics
import Testing
@testable import FocusBakery

/// Spec 13's in-world reachability criterion, checked as geometry rather than
/// by eye — the same way spec 06 checks the chrome clears the room.
///
/// The arithmetic the spec spells out is the whole point: a 16×16 tile at ×2 is
/// 32pt, which does **not** clear the 44pt minimum, so no in-world region can be
/// one tile. The case's own extent already clears it; the baker's does not, and
/// that is what `grown(toAtLeast:within:)` is for.
@Suite("Room accessibility")
struct RoomAccessibilityTests {
    private struct Phone {
        let name: String
        let size: CGSize
        let safeAreaTop: CGFloat
        let safeAreaBottom: CGFloat

        var scene: CGRect {
            ChromeLayout(size: size, safeAreaTop: safeAreaTop, safeAreaBottom: safeAreaBottom).scene
        }
        var layout: RoomLayout { RoomLayout(fitting: scene.size) }
        var plan: RoomPlan { RoomPlan(fitting: layout) }
        var bounds: CGRect { CGRect(origin: .zero, size: scene.size) }
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

    /// Every region the overlay exposes, at every position the baker can be
    /// standing in — the phase decides which of the three is drawn, so all three
    /// have to hold.
    private func regions(of phone: Phone) -> [(String, CGRect)] {
        let layout = phone.layout
        let plan = phone.plan
        return [
            ("the oven", plan.ovenRegion(in: layout)),
            ("the display case", plan.caseRegion(in: layout)),
            ("the baker at the station", plan.bakerRegion(standingOn: plan.stationTile, in: layout)),
            ("the baker resting", plan.bakerRegion(standingOn: plan.restTile, in: layout)),
            ("the baker at the case", plan.bakerRegion(standingOn: plan.deliverTile, in: layout)),
        ]
    }

    @Test("Every in-world element clears the minimum target on every supported iPhone")
    func inWorldElementsAreBigEnough() {
        let minimum = ChromeLayout.minimumTarget
        for phone in Self.phones {
            let layout = phone.layout
            let bounds = phone.bounds
            for (fixture, region) in regions(of: phone) {
                let frame = layout.inViewSpace(region).grown(toAtLeast: minimum, within: bounds)
                #expect(frame.width >= minimum,
                        "\(phone.name): \(fixture) is \(frame.width)pt wide")
                #expect(frame.height >= minimum,
                        "\(phone.name): \(fixture) is \(frame.height)pt tall")
                // Grown outwards, never shrunk: an element that no longer covers
                // the sprite it names would land on the wrong thing.
                #expect(frame.contains(layout.inViewSpace(region)),
                        "\(phone.name): \(fixture) \(frame) no longer covers its sprite")
                #expect(bounds.contains(frame),
                        "\(phone.name): \(fixture) \(frame) escaped the room \(bounds)")
            }
        }
    }

    /// The spec's own worked example, kept honest in both directions. The case
    /// clears on its own because it spans the counter line — if it ever stops,
    /// the padding would hide that rather than the test catching it. The baker
    /// is one tile wide and never clears, which is why the padding exists.
    @Test("The case clears unaided and the baker does not")
    func theSpecsWorkedExampleStillHolds() {
        for phone in Self.phones {
            let layout = phone.layout
            let plan = phone.plan
            let caseRegion = plan.caseRegion(in: layout)
            #expect(caseRegion.width >= ChromeLayout.minimumTarget, "\(phone.name)")
            #expect(caseRegion.height >= ChromeLayout.minimumTarget, "\(phone.name)")

            #expect(plan.bakerRegion(standingOn: plan.stationTile, in: layout).width
                    < ChromeLayout.minimumTarget,
                    "\(phone.name): a one-tile region now clears 44pt unaided")
        }
    }

    /// Growth is padding, not repositioning: a region already over the minimum
    /// is handed back untouched, so nothing that fits gets nudged off the sprite
    /// it describes.
    @Test("A region that already clears the target is left alone")
    func growthOnlyGrows() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        let roomy = CGRect(x: 100, y: 100, width: 96, height: 60)
        #expect(roomy.grown(toAtLeast: 44, within: bounds) == roomy)

        // One axis short: only that axis moves.
        let narrow = CGRect(x: 100, y: 100, width: 32, height: 64)
        let grown = narrow.grown(toAtLeast: 44, within: bounds)
        #expect(grown.width == 44)
        #expect(grown.height == narrow.height)
        #expect(grown.midX == narrow.midX)
        #expect(grown.midY == narrow.midY)
    }

    /// A fixture against the room's edge is the case that would otherwise pad
    /// itself off screen — the display case stands at column 0.
    @Test("Growth at the room's edge stays on screen")
    func growthAtTheEdgeStaysOnScreen() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        let atTheEdge = CGRect(x: 0, y: 0, width: 32, height: 32)
        let grown = atTheEdge.grown(toAtLeast: 44, within: bounds)
        #expect(grown.minX >= 0)
        #expect(grown.minY >= 0)
        #expect(grown.width == 44)
        #expect(grown.height == 44)

        // And a target the screen itself cannot hold pins rather than runs off.
        let tiny = CGRect(x: 0, y: 0, width: 10, height: 10)
        #expect(tiny.grown(toAtLeast: 44, within: CGRect(x: 0, y: 0, width: 20, height: 20)).origin
                == .zero)
    }
}
