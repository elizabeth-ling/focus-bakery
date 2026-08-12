import SpriteKit
import SwiftUI

/// Temporary. Spec 01 says to prove the pipeline before anything is layered on
/// top, and two of its acceptance criteria are things you can only check by
/// looking: a bitmap `00:00` at a uniform pixel size across the smallest and
/// largest iPhones, and a sprite crossing the scene without shimmering.
///
/// This is the surface those checks are made against. It renders the pipeline
/// and nothing else — no timer, no persistence, no state. Spec 06 replaces it
/// with the real room, and this file goes when it does.
@MainActor
final class PixelProofScene: SKScene {
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = SKColor(red: 0.08, green: 0.07, blue: 0.11, alpha: 1)
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuild()
    }

    private func rebuild() {
        removeAllChildren()
        guard size.width > 0, size.height > 0 else { return }

        let layout = RoomLayout(fitting: size)
        addFloor(layout)
        addReadout(layout)
        addWalker(layout)
    }

    /// A checkerboard of whole tiles. Two jobs: it shows that the room is whole
    /// tiles, and it leaves the sub-tile remainder visible as background at the
    /// edges rather than hiding it behind a stretched floor.
    private func addFloor(_ layout: RoomLayout) {
        for row in 0..<layout.rows {
            for column in 0..<layout.columns {
                let tile = SKSpriteNode(
                    color: (row + column).isMultiple(of: 2)
                        ? SKColor(red: 0.29, green: 0.24, blue: 0.29, alpha: 1)
                        : SKColor(red: 0.25, green: 0.20, blue: 0.25, alpha: 1),
                    size: CGSize(width: layout.tileSize, height: layout.tileSize)
                )
                tile.anchorPoint = .zero
                tile.position = layout.tileRect(column: column, row: row).origin
                addChild(tile)
            }
        }
    }

    /// `00:00` large, and the numbers that produced it underneath. Reading the
    /// scale and tile count straight off the screenshot is what makes a
    /// three-device comparison a check rather than a vibe.
    private func addReadout(_ layout: RoomLayout) {
        let timer = BitmapTextNode("00:00", scale: layout.scale * 2)
        timer.place(centeredOn: CGPoint(
            x: layout.roomFrame.midX,
            y: layout.roomFrame.maxY - layout.tileSize * 2
        ))
        addChild(timer)

        let metrics = BitmapTextNode(
            "x\(layout.scale) \(layout.columns)x\(layout.rows) tiles",
            scale: layout.scale
        )
        metrics.place(centeredOn: CGPoint(
            x: layout.roomFrame.midX,
            y: layout.roomFrame.maxY - layout.tileSize * 3
        ))
        addChild(metrics)
    }

    /// A sprite crossing the room and back, forever, so the no-shimmer
    /// criterion has something to be judged on. The walk cycle animates on its
    /// own clock; the movement is `RoomLayout.walk`, which is the thing under
    /// test.
    private func addWalker(_ layout: RoomLayout) {
        let feet = layout.tileRect(column: 0, row: layout.rows - 3).minY
        let left = layout.roomFrame.minX
        let right = layout.roomFrame.maxX - layout.tileSize

        let walker = makeWalker(layout)
        walker.position = CGPoint(x: left, y: feet)
        addChild(walker)

        // Slow enough that a shimmering sprite would be obvious, and an odd
        // number of seconds so the steps do not line up with the frame clock.
        let artPixelsPerSecond = Double(right - left) / Double(layout.scale) / 7

        walker.run(.repeatForever(.sequence([
            face("right", on: walker),
            layout.walk(
                from: CGPoint(x: left, y: feet),
                to: CGPoint(x: right, y: feet),
                artPixelsPerSecond: artPixelsPerSecond
            ),
            face("left", on: walker),
            layout.walk(
                from: CGPoint(x: right, y: feet),
                to: CGPoint(x: left, y: feet),
                artPixelsPerSecond: artPixelsPerSecond
            ),
        ])))
    }

    /// The walk cycle runs on its own clock, keyed so a change of direction
    /// replaces it. It deliberately is not grouped with the movement: an
    /// endlessly repeating animation never reports finishing, so a group
    /// holding both would never reach the turn at the far wall.
    private func face(_ direction: String, on walker: SKSpriteNode) -> SKAction {
        SKAction.run {
            let frames = self.walkFrames(facing: direction)
            guard frames.count > 1 else { return }
            walker.run(
                .repeatForever(.animate(with: frames, timePerFrame: 0.12, resize: false, restore: false)),
                withKey: "cycle"
            )
        }
    }

    private func walkFrames(facing direction: String) -> [SKTexture] {
        PixelTexture.names(in: .baker, prefix: "baker_walk_\(direction)")
            .map { PixelTexture.named($0, in: .baker) }
    }

    /// The pack is a licensed build artifact (14), so a checkout without it
    /// still has to render something that moves — the motion is what is on
    /// trial here, not the art.
    private func makeWalker(_ layout: RoomLayout) -> SKSpriteNode {
        guard let texture = walkFrames(facing: "right").first else {
            let placeholder = SKSpriteNode(
                color: SKColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1),
                size: CGSize(width: layout.tileSize, height: layout.tileSize)
            )
            placeholder.anchorPoint = .zero
            return placeholder
        }

        let walker = SKSpriteNode(texture: texture)
        walker.anchorPoint = .zero
        walker.size = CGSize(
            width: texture.size().width * CGFloat(layout.scale),
            height: texture.size().height * CGFloat(layout.scale)
        )
        return walker
    }
}

struct PixelProofView: View {
    /// Held rather than computed in `body`: a fresh scene per layout pass would
    /// restart the walk on every redraw.
    @State private var scene: PixelProofScene = {
        let scene = PixelProofScene()
        // Anything but `.resizeFill` lets SpriteKit scale the scene to fit,
        // which is a fractional magnification on top of ours — the one thing
        // spec 01 exists to prevent.
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
