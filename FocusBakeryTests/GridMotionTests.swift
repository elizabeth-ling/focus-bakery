import SpriteKit
import Testing
@testable import FocusBakery

@Suite("Grid motion")
struct GridMotionTests {
    let layout = RoomLayout(fitting: CGSize(width: 393, height: 852))

    /// Spec 01's no-shimmer criterion, stated as arithmetic: a walk that never
    /// leaves the grid cannot crawl, whatever it is textured with.
    @Test("Every position on a walk is a whole art pixel")
    func walksStayOnTheGrid() {
        let walks = [
            (CGPoint(x: 64, y: 200), CGPoint(x: 320, y: 200)),
            (CGPoint(x: 320, y: 200), CGPoint(x: 64, y: 200)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 100, y: 500)),
            (CGPoint(x: 40, y: 600), CGPoint(x: 300, y: 120)),
            (CGPoint(x: 7.3, y: 11.9), CGPoint(x: 199.5, y: 480.2)),
        ]

        for (start, destination) in walks {
            for point in layout.walkPath(from: start, to: destination) {
                #expect(point.x.truncatingRemainder(dividingBy: CGFloat(layout.scale)) == 0)
                #expect(point.y.truncatingRemainder(dividingBy: CGFloat(layout.scale)) == 0)
            }
        }
    }

    @Test("A walk begins where it was told to and arrives exactly")
    func walksStartAndEndOnTarget() {
        let path = layout.walkPath(from: CGPoint(x: 64, y: 200), to: CGPoint(x: 320, y: 456))

        #expect(path.first == CGPoint(x: 64, y: 200))
        #expect(path.last == CGPoint(x: 320, y: 456))
    }

    @Test("Fractional endpoints are snapped rather than carried along")
    func fractionalEndpointsSnap() {
        let path = layout.walkPath(from: CGPoint(x: 7.3, y: 11.9), to: CGPoint(x: 99.4, y: 11.9))

        #expect(path.first == CGPoint(x: 8, y: 12))
        #expect(path.last == CGPoint(x: 100, y: 12))
    }

    /// A step that jumped two pixels would read as a stutter, and one that went
    /// backwards would read as a jitter. Neither is shimmer, but both are the
    /// same class of bug: motion that does not advance evenly.
    @Test("Each step advances at most one art pixel per axis and never backtracks")
    func stepsAdvanceEvenly() {
        let path = layout.walkPath(from: CGPoint(x: 40, y: 600), to: CGPoint(x: 300, y: 120))
        let step = CGFloat(layout.scale)

        for (previous, next) in zip(path, path.dropFirst()) {
            #expect(next.x - previous.x >= 0)
            #expect(next.y - previous.y <= 0)
            #expect(abs(next.x - previous.x) <= step)
            #expect(abs(next.y - previous.y) <= step)
        }
    }

    @Test("A walk covers every art pixel along its dominant axis")
    func walkCoversTheDistance() {
        let path = layout.walkPath(from: CGPoint(x: 64, y: 200), to: CGPoint(x: 320, y: 264))

        // 256pt of travel at ×2 is 128 art pixels, so 128 steps plus the start.
        #expect(path.count == 129)
    }

    @Test("Going nowhere is one position, not an empty path")
    func standingStillIsOnePosition() {
        #expect(layout.walkPath(from: CGPoint(x: 64, y: 200), to: CGPoint(x: 64, y: 200)).count == 1)
        // Less than half an art pixel apart is the same art pixel.
        #expect(layout.walkPath(from: CGPoint(x: 64, y: 200), to: CGPoint(x: 64.4, y: 200)).count == 1)
    }

    /// This is also what proves the node is never mid-move. The walk is 128 art
    /// pixels, so its waits alone account for 128 ÷ 16 = 8 seconds. Any move in
    /// the sequence given a duration — anything that would interpolate, and so
    /// shimmer — would show up here as time the waits cannot explain.
    @Test("The action takes distance ÷ speed to run, and spends none of it moving")
    func actionDurationIsAllWaiting() {
        let action = layout.walk(
            from: CGPoint(x: 64, y: 200),
            to: CGPoint(x: 320, y: 200),
            artPixelsPerSecond: 16
        )

        #expect(abs(action.duration - 8) < 0.001)
    }

    @Test("A standstill and a zero speed both resolve instead of hanging")
    func degenerateWalksAreInstant() {
        let standstill = layout.walk(
            from: CGPoint(x: 64, y: 200),
            to: CGPoint(x: 64, y: 200),
            artPixelsPerSecond: 16
        )
        let stopped = layout.walk(
            from: CGPoint(x: 64, y: 200),
            to: CGPoint(x: 320, y: 200),
            artPixelsPerSecond: 0
        )

        #expect(standstill.duration == 0)
        #expect(stopped.duration == 0)
    }
}
