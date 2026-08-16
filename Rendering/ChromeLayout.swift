import CoreGraphics

/// Where the chrome sits, and how much screen is left for the bakery.
///
/// The readouts used to float over a full-bleed room, which made "keep chrome
/// sparse" a geometry problem rather than an editorial one: a bar pinned to the
/// top safe area lands squarely on the oven, the room's whole "something is
/// baking" signal (05), so it had to start clear of the oven's trailing edge and
/// live in whatever was left. The tray settles that by taking the top of the
/// screen outright and letting the room have the rest. Chrome that is never over
/// the bakery cannot obscure it, and the readouts get a comfortable row instead
/// of the gap beside the oven.
///
/// View coordinates — y down from the top — because this is chrome's geometry,
/// not the scene's. The room is laid out at `scene.size`, so a scene coordinate
/// becomes a screen one by way of `scene.origin`.
struct ChromeLayout: Equatable {
    /// Spec 13's minimum tap target, which is also the floor on anything the
    /// chrome offers.
    static let minimumTarget: CGFloat = 44

    /// The row inside the tray that the readouts and the settings entry sit in.
    /// Comfortably over the minimum target: the tray is the one piece of chrome
    /// that costs no bakery, so height here is free.
    private static let readoutArtPixels = 26
    /// `tray_edge`'s two halves: the lip and brass rail that finish the tray,
    /// then the shadow it drops past its own edge onto the room.
    private static let lipArtPixels = 7
    private static let shadowArtPixels = 2
    /// How far the readouts stand in from the screen's edges.
    private static let insetArtPixels = 8

    /// The tray across the top: full width, from the screen's top edge down
    /// through the rail. Its material runs up under the status bar rather than
    /// starting below it, so the notch band is part of the tray instead of a
    /// strip of nothing above it.
    let tray: CGRect

    /// Where `tray_edge` draws — the tray's bottom rows plus the shadow, which
    /// hangs past `tray.maxY` over the room.
    let trayEdge: CGRect

    /// The readout row inside the tray, below the status bar.
    let content: CGRect

    /// What is left for the room, and the size the scene is laid out at.
    let scene: CGRect

    /// The one floating control — "+" while a bake can be started, the way out
    /// of one while it runs. In screen coordinates, like everything else here.
    let action: CGRect

    init(size: CGSize, safeAreaTop: CGFloat, safeAreaBottom: CGFloat) {
        let chromePixel = CGFloat(PixelGrid.chromeScale)
        // Rounded up to a whole chrome pixel. The tray's depth is what offsets
        // the room, and half a point of offset would put a scene that snapped
        // every sprite to the grid half a pixel off it.
        let safeTop = (safeAreaTop / chromePixel).rounded(.up) * chromePixel
        let lip = CGFloat(Self.lipArtPixels) * chromePixel
        let readouts = CGFloat(Self.readoutArtPixels) * chromePixel
        let inset = CGFloat(Self.insetArtPixels) * chromePixel

        tray = CGRect(x: 0, y: 0, width: size.width, height: safeTop + readouts + lip)
        trayEdge = CGRect(
            x: 0,
            y: tray.maxY - lip,
            width: size.width,
            height: lip + CGFloat(Self.shadowArtPixels) * chromePixel
        )
        content = CGRect(
            x: inset,
            y: safeTop,
            width: max(0, size.width - inset * 2),
            height: readouts
        )
        scene = CGRect(
            x: 0,
            y: tray.maxY,
            width: size.width,
            height: max(0, size.height - tray.maxY)
        )

        let layout = RoomLayout(fitting: scene.size)
        let plan = RoomPlan(fitting: layout)
        let room = layout.roomFrame
        // A quarter tile, so the chrome breathes at the room's rate rather than
        // at a point value that would read tighter on a larger phone.
        let gap = layout.tileSize / 4

        // Held above the door rather than at a fixed inset off the bottom: the
        // door is the one fixture this low in the room (05), and on a phone with
        // no home indicator the safe area alone would let the button sit on it.
        let door = layout.inViewSpace(
            layout.tileRect(column: plan.doorTile.column, row: plan.doorTile.row)
        )
        // Two tiles: the authored plate is 32 art pixels, and chrome magnifies
        // art by the same whole number the room does (01).
        let side = layout.tileSize * 2
        let bottom = min(scene.height - safeAreaBottom - gap, door.minY - gap)
        // Snapped in the room's coordinates and only then moved down past the
        // tray, so the plate lands on the grid the room was drawn on.
        action = CGRect(
            x: layout.snap(room.midX - side / 2),
            y: layout.snap(bottom - side),
            width: side,
            height: side
        ).offsetBy(dx: scene.minX, dy: scene.minY)
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
