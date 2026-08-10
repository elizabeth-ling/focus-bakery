import CoreGraphics

/// The numbers that keep every pixel in the app the same size.
///
/// Spec 01's hard rules are arithmetic, not style: art is authored at one tile
/// size and magnified by a whole number of points, never anything in between.
/// Everything that draws goes through these constants or through `RoomLayout`.
enum PixelGrid {
    /// Spec 14 standardizes on 32×32. The pack ships 16×16 and 48×48 beside it,
    /// so a wrong path is one character away.
    static let artPixelsPerTile = 32

    /// Integer scales the room may resolve to, largest first. There is no ×1:
    /// a 32pt tile would put more than a dozen tiles across a phone and read as
    /// a map rather than a room.
    static let candidateScales = [4, 3, 2]

    /// Below this the room stops being a bakery with a back and a front of
    /// house (05), so a larger scale that cannot seat it is rejected. This is
    /// what resolves the scale to ×2 on every supported iPhone rather than
    /// letting big devices step to ×3 and show *fewer*, bigger tiles.
    static let smallestUsefulRoom = (columns: 5, rows: 8)

    /// Points per art pixel for SwiftUI chrome — spec 01's "1 art pixel = N
    /// screen points" for the off-scene tier. It matches the room's ×2 so a
    /// chrome pixel and a room pixel are the same physical size; the chrome
    /// *grid* still varies with the device, which is what makes UI fit.
    static let chromeScale = 2

    /// Rounds a point value to a whole art pixel at the given scale. Every
    /// position in the app lands on one of these.
    static func snap(_ value: CGFloat, at scale: Int) -> CGFloat {
        (value / CGFloat(scale)).rounded() * CGFloat(scale)
    }
}

/// Resolves an available size into a whole-number scale, whole tiles, and the
/// margin that absorbs what is left over.
///
/// The tile size is fixed and the room dimensions flex, never the other way
/// around: a larger phone sees slightly more bakery, not bigger pixels.
struct RoomLayout: Equatable {
    /// Points per art pixel. Always a whole number — the entire point of this type.
    let scale: Int
    let columns: Int
    let rows: Int
    let sceneSize: CGSize

    /// One tile in points.
    var tileSize: CGFloat { CGFloat(PixelGrid.artPixelsPerTile * scale) }

    /// The room inside the scene. What the scene has left over is wall margin;
    /// nothing is ever stretched to close the gap.
    let roomFrame: CGRect

    init(fitting sceneSize: CGSize) {
        self.sceneSize = sceneSize

        let scale = PixelGrid.candidateScales.first { candidate in
            let tile = CGFloat(PixelGrid.artPixelsPerTile * candidate)
            return Int(sceneSize.width / tile) >= PixelGrid.smallestUsefulRoom.columns
                && Int(sceneSize.height / tile) >= PixelGrid.smallestUsefulRoom.rows
        }
        // A scene too small to seat the smallest useful room still has to render
        // something, so fall back to the finest scale rather than failing.
        self.scale = scale ?? PixelGrid.candidateScales.last ?? 2

        let tile = CGFloat(PixelGrid.artPixelsPerTile * self.scale)
        columns = max(1, Int(sceneSize.width / tile))
        rows = max(1, Int(sceneSize.height / tile))

        let roomSize = CGSize(width: CGFloat(columns) * tile, height: CGFloat(rows) * tile)
        // The margin is split evenly but rounded down to a whole art pixel, so
        // the room's origin never lands on a half pixel. An odd point of
        // remainder goes to the trailing edge, where nothing is drawn.
        let step = CGFloat(self.scale)
        let leading = (((sceneSize.width - roomSize.width) / 2) / step).rounded(.down) * step
        let bottom = (((sceneSize.height - roomSize.height) / 2) / step).rounded(.down) * step
        roomFrame = CGRect(origin: CGPoint(x: max(0, leading), y: max(0, bottom)), size: roomSize)
    }

    /// Rounds to a whole art pixel. Sprite positions go through this so no
    /// sprite ever straddles a source pixel.
    func snap(_ value: CGFloat) -> CGFloat {
        PixelGrid.snap(value, at: scale)
    }

    func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: snap(point.x), y: snap(point.y))
    }

    /// A tile in scene coordinates, with row 0 at the back wall. Rows count down
    /// the screen while SpriteKit's y counts up, so fixtures can be placed from
    /// the back of the room forwards (05) without every call site flipping y.
    func tileRect(column: Int, row: Int) -> CGRect {
        CGRect(
            x: roomFrame.minX + CGFloat(column) * tileSize,
            y: roomFrame.maxY - CGFloat(row + 1) * tileSize,
            width: tileSize,
            height: tileSize
        )
    }
}
