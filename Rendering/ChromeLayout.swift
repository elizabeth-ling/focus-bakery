import CoreGraphics

/// Where the overlay may sit without covering the bakery.
///
/// Spec 06's chrome floats over the room rather than sitting beside it, so
/// "keep it sparse" is not enough on its own: a bar pinned to the top safe area
/// lands squarely on the oven, which is the room's whole "something is baking"
/// signal (05). Both slots are therefore resolved from the same `RoomLayout` the
/// scene lays the room out with, so they move with the fixtures instead of being
/// eyeballed once on one device.
///
/// View coordinates — y down from the top — because this is chrome's geometry,
/// not the scene's.
struct ChromeLayout: Equatable {
    /// Spec 13's minimum tap target, which is also the floor on anything the
    /// chrome offers.
    static let minimumTarget: CGFloat = 44

    /// The persistent readouts and the settings entry: a strip across the top of
    /// the room, starting clear of the oven.
    let bar: CGRect

    /// The one floating control — "+" while a bake can be started, the way out
    /// of one while it runs.
    let action: CGRect

    init(size: CGSize, safeAreaTop: CGFloat, safeAreaBottom: CGFloat) {
        let layout = RoomLayout(fitting: size)
        let plan = RoomPlan(fitting: layout)
        let room = layout.roomFrame
        // A quarter tile, so the chrome breathes at the room's rate rather than
        // at a point value that would read tighter on a larger phone.
        let gap = layout.tileSize / 4

        let oven = layout.inViewSpace(plan.ovenRegion(in: layout))
        let leading = max(room.minX, oven.maxX) + gap
        bar = CGRect(
            x: leading,
            y: safeAreaTop + gap,
            width: max(0, room.maxX - gap - leading),
            height: Self.minimumTarget
        )

        // Held above the door rather than at a fixed inset off the bottom: the
        // door is the one fixture this low in the room (05), and on a phone with
        // no home indicator the safe area alone would let the button sit on it.
        let door = layout.inViewSpace(
            layout.tileRect(column: plan.doorTile.column, row: plan.doorTile.row)
        )
        // Two tiles: the authored plate is 32 art pixels, and chrome magnifies
        // art by the same whole number the room does (01).
        let side = layout.tileSize * 2
        let bottom = min(size.height - safeAreaBottom - gap, door.minY - gap)
        action = CGRect(
            x: layout.snap(room.midX - side / 2),
            y: layout.snap(bottom - side),
            width: side,
            height: side
        )
    }
}

extension RoomLayout {
    /// A scene rect in the view's coordinates. SpriteKit's y counts up from the
    /// bottom and SwiftUI's counts down from the top; this is that flip and
    /// nothing else.
    func inViewSpace(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: sceneSize.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
