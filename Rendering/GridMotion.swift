import SpriteKit

/// Movement that lands on a whole art pixel on every frame.
///
/// Spec 01 rule 4 bans sub-pixel animation, and `SKAction.move(to:duration:)`
/// is exactly what it bans: it interpolates continuously, so on most frames a
/// sprite sits between two source pixels. The renderer then draws some of its
/// pixels one screen-pixel wider than others, and the edges crawl for as long as
/// the sprite is moving — the shimmer the spec is worried about.
///
/// A walk is therefore a series of jumps, not a tween. The sprite is on one art
/// pixel or the next, never between them.
extension RoomLayout {
    /// Every position a walk passes through, starting at `start`.
    ///
    /// Separate from the action because this is the part worth asserting on: an
    /// `SKAction` hides its positions, a list of points does not.
    func walkPath(from start: CGPoint, to destination: CGPoint) -> [CGPoint] {
        let origin = snap(start)
        let target = snap(destination)
        let step = CGFloat(scale)

        let columns = Int(((target.x - origin.x) / step).rounded())
        let rows = Int(((target.y - origin.y) / step).rounded())

        // One step advances at most one art pixel per axis, so the longer axis
        // sets the count and the shorter one lands on a subset of those frames.
        let steps = max(abs(columns), abs(rows))
        guard steps > 0 else { return [origin] }

        return (0...steps).map { index in
            let progress = CGFloat(index) / CGFloat(steps)
            return CGPoint(
                x: origin.x + (CGFloat(columns) * progress).rounded() * step,
                y: origin.y + (CGFloat(rows) * progress).rounded() * step
            )
        }
    }

    /// Walks a node along `walkPath` at a whole number of art pixels per second.
    ///
    /// Speed is in art pixels rather than points so a walk covers the same
    /// ground at the same pace whatever the device resolved to.
    func walk(
        from start: CGPoint,
        to destination: CGPoint,
        artPixelsPerSecond: Double
    ) -> SKAction {
        let path = walkPath(from: start, to: destination)
        let placeAtStart = SKAction.move(to: path[0], duration: 0)
        guard path.count > 1, artPixelsPerSecond > 0 else { return placeAtStart }

        let hold = SKAction.wait(forDuration: 1 / artPixelsPerSecond)
        let jumps = path.dropFirst().flatMap { point in
            [hold, SKAction.move(to: point, duration: 0)]
        }
        return .sequence([placeAtStart] + jumps)
    }
}
