import SpriteKit

/// The bakery room. Renders app state; owns none of it (spec 05).
///
/// Everything the scene knows arrives through `apply(_:)` as a `Model`, and
/// everything it has to say travels up through `onEvent`. No timer arithmetic,
/// persistence, or notification scheduling lives here. The one mutable thing
/// the scene does hold — where the baker is and what it is doing — is
/// presentation, re-derived from the model whenever the room is rebuilt.
///
/// Built placeholder-first: every fixture renders as a colored block when its
/// atlas is absent, so a checkout without the licensed pack (14) still shows
/// the full choreography.
@MainActor
final class BakeryScene: SKScene {

    /// What the app layer wants on screen. A value, applied wholesale, so the
    /// scene can never hold state the app has moved past.
    struct Model: Equatable {
        enum Phase: Equatable {
            case idle
            case baking(secondsRemaining: Int)
            /// A bake completed while the user watched: the payoff walk is
            /// owed. A bake that resolved while the app was away never gets
            /// this phase — its treat is simply in `treats` (specs 05, 06).
            case delivering(RecipeID)
        }

        var phase: Phase = .idle
        /// Today's case contents in completion order. Spec 08 owns quantities
        /// and overflow; the scene shows what fits on the shelf.
        var treats: [RecipeID] = []
        var coins: Int = 0
        var reduceMotion: Bool = false
    }

    enum Event: Equatable {
        /// The carried treat just landed in the case.
        case treatPlaced
        /// Deliver walk and celebrate beat done; the app can retire the outcome.
        case deliveryFinished
        /// A tap landed on the display case. Spec 08 presents the sheet.
        case caseTapped
    }

    /// The sprite state machine from spec 05's table. `BakerDirector` picks a
    /// target from app state; arrival, placement and the celebrate beat advance
    /// it internally. Every state is entered through the single `enter(_:)`,
    /// which cancels whatever was running first — that is what makes any state
    /// reachable from any other without stranding the baker mid-walk.
    enum Activity: Equatable, CaseIterable {
        case resting
        case walkingToStation
        case working
        case delivering
        case celebrating
    }

    enum Facing: String {
        case right, up, left, down

        init(from: CGPoint, to: CGPoint) {
            let dx = to.x - from.x
            let dy = to.y - from.y
            if abs(dx) >= abs(dy) {
                self = dx >= 0 ? .right : .left
            } else {
                self = dy > 0 ? .up : .down
            }
        }
    }

    var onEvent: ((Event) -> Void)?

    private(set) var model = Model()
    private(set) var activity: Activity = .resting

    /// Everything that exists once the scene has a size. Grouped so a resize
    /// can throw the whole room away and lay it out again.
    private struct Stage {
        let layout: RoomLayout
        let plan: RoomPlan
        let baker: SKSpriteNode
        let oven: SKSpriteNode
        let shelf: SKNode
        let timer: BitmapTextNode
        let tag: BitmapTextNode
        let coins: BitmapTextNode
        let timerCenter: CGPoint
        let tagCenter: CGPoint
        let coinsCenter: CGPoint
        let caseRegion: CGRect
    }

    private var stage: Stage?
    private var carried: SKSpriteNode?
    private var placedDeliveredTreat = false
    private var renderedShelf: [RecipeID]?

    private enum Pace {
        static let walkArtPixelsPerSecond: Double = 64
        static let walkFrameTime = 0.1
        static let idleFrameTime = 0.18
        static let workFrameTime = 0.15
        static let ovenFrameTime = 0.25
    }

    private enum Palette {
        static let background = SKColor(red: 0.08, green: 0.07, blue: 0.11, alpha: 1)
        static let wall = SKColor(red: 0.36, green: 0.25, blue: 0.22, alpha: 1)
        static let backFloorA = SKColor(red: 0.47, green: 0.36, blue: 0.28, alpha: 1)
        static let backFloorB = SKColor(red: 0.44, green: 0.34, blue: 0.27, alpha: 1)
        static let frontFloorA = SKColor(red: 0.63, green: 0.50, blue: 0.37, alpha: 1)
        static let frontFloorB = SKColor(red: 0.60, green: 0.47, blue: 0.35, alpha: 1)
        static let counter = SKColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1)
        static let prep = SKColor(red: 0.58, green: 0.45, blue: 0.36, alpha: 1)
        static let seat = SKColor(red: 0.42, green: 0.29, blue: 0.22, alpha: 1)
        static let door = SKColor(red: 0.76, green: 0.60, blue: 0.40, alpha: 1)
        static let oven = SKColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 1)
        static let ovenGlow = SKColor(red: 0.95, green: 0.45, blue: 0.25, alpha: 1)
        static let baker = SKColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1)
        static let treat = SKColor(red: 0.93, green: 0.76, blue: 0.44, alpha: 1)
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = Palette.background
        rebuildIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildIfNeeded()
    }

    /// The scene's entire input. Cheap when nothing relevant changed, so the
    /// app layer can call it every tick and on every state edge.
    func apply(_ model: Model) {
        self.model = model
        rebuildIfNeeded()
        guard stage != nil else { return }
        render()
        if let next = BakerDirector.target(for: model.phase, current: activity) {
            enter(next)
        }
    }

    /// SpriteView hands the scene transient sizes while SwiftUI settles its
    /// layout, and the didChangeSize calls can arrive in any order. The room
    /// self-heals on the next rendered frame; the check is two comparisons.
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        rebuildIfNeeded()
    }

    /// Depth is the sprite's place in the room, not its place in the code: a
    /// lower base y is nearer the viewer and draws on top (spec 05).
    override func didEvaluateActions() {
        guard let stage else { return }
        stage.baker.zPosition = depth(ofBaseY: stage.baker.position.y, in: stage.layout)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let stage, let touch = touches.first else { return }
        if stage.caseRegion.contains(touch.location(in: self)) {
            onEvent?(.caseTapped)
        }
    }

    // MARK: - Introspection (tests and the app layer read, never write)

    var isOvenRunning: Bool { stage?.oven.action(forKey: "bake") != nil }
    var bakerPosition: CGPoint? { stage?.baker.position }
    var displayedTimer: String { stage?.timer.text ?? "" }
    var visibleTreatCount: Int { stage?.shelf.children.count ?? 0 }

    // MARK: - Building the room

    private func rebuildIfNeeded() {
        guard size.width > 0, size.height > 0 else { return }
        if let stage, stage.layout.sceneSize == size { return }
        rebuild()
    }

    private func rebuild() {
        removeAllChildren()
        carried = nil
        renderedShelf = nil

        let layout = RoomLayout(fitting: size)
        let plan = RoomPlan(fitting: layout)

        addFloor(layout, plan)
        addPrepCounter(layout, plan)
        addCounterLine(layout, plan)
        addSeats(layout, plan)
        let oven = addOven(layout, plan)
        let caseRegion = addCase(layout, plan)

        let shelf = SKNode()
        addChild(shelf)

        let baker = makeBaker(layout)
        addChild(baker)

        let timer = BitmapTextNode("", scale: layout.scale * 2)
        let tag = BitmapTextNode("", scale: layout.scale)
        let coins = BitmapTextNode("", scale: layout.scale)
        for text in [timer, tag, coins] {
            text.zPosition = 1_000
            addChild(text)
        }

        stage = Stage(
            layout: layout,
            plan: plan,
            baker: baker,
            oven: oven,
            shelf: shelf,
            timer: timer,
            tag: tag,
            coins: coins,
            // The HUD lives in the open floor between station and counter: the
            // top of the room sits under the status bar and Dynamic Island in
            // a full-bleed scene, so nothing readable may anchor to the wall.
            timerCenter: CGPoint(
                x: layout.roomFrame.midX,
                y: layout.tileRect(column: 0, row: plan.stationTile.row + 1).maxY
                    - layout.tileSize * 0.3
            ),
            tagCenter: CGPoint(
                x: layout.roomFrame.midX,
                y: layout.tileRect(column: 0, row: plan.stationTile.row + 1).maxY
                    - layout.tileSize * 0.75
            ),
            coinsCenter: CGPoint(
                x: layout.roomFrame.maxX - layout.tileSize * 0.75,
                y: layout.roomFrame.maxY - layout.tileSize * 1.5
            ),
            caseRegion: caseRegion
        )

        render()

        // Settle straight into the state the model implies rather than
        // replaying transitions: coming back after a bake ended must show a
        // finished room, not a deliver walk out of context (specs 05, 06).
        let settled: Activity = switch model.phase {
        case .idle: .resting
        case .baking: .working
        case .delivering: .delivering
        }
        baker.position = layout.point(of: anchor(for: settled, in: plan))
        enter(settled)
    }

    private func anchor(for activity: Activity, in plan: RoomPlan) -> RoomTile {
        switch activity {
        case .resting: plan.restTile
        case .walkingToStation, .working, .delivering: plan.stationTile
        case .celebrating: plan.deliverTile
        }
    }

    private func addFloor(_ layout: RoomLayout, _ plan: RoomPlan) {
        for row in 0..<layout.rows {
            for column in 0..<layout.columns {
                let color: SKColor = if row == plan.wallRow {
                    Palette.wall
                } else if row < plan.counterRow {
                    (row + column).isMultiple(of: 2) ? Palette.backFloorA : Palette.backFloorB
                } else {
                    (row + column).isMultiple(of: 2) ? Palette.frontFloorA : Palette.frontFloorB
                }
                let tile = SKSpriteNode(
                    color: color,
                    size: CGSize(width: layout.tileSize, height: layout.tileSize)
                )
                tile.anchorPoint = .zero
                tile.position = layout.tileRect(column: column, row: row).origin
                tile.zPosition = -20
                addChild(tile)
            }
        }

        let door = SKSpriteNode(
            color: Palette.door,
            size: CGSize(width: layout.tileSize, height: layout.tileSize / 2)
        )
        door.anchorPoint = .zero
        door.position = layout.point(of: plan.doorTile)
        door.zPosition = -19
        addChild(door)
    }

    private func addPrepCounter(_ layout: RoomLayout, _ plan: RoomPlan) {
        for column in plan.prepColumns {
            let block = SKSpriteNode(
                color: Palette.prep,
                size: CGSize(width: layout.tileSize, height: layout.tileSize * 1.25)
            )
            block.anchorPoint = .zero
            block.position = layout.point(of: RoomTile(column: column, row: plan.prepRow))
            block.zPosition = depth(ofBaseY: block.position.y, in: layout)
            addChild(block)
        }
    }

    private func addCounterLine(_ layout: RoomLayout, _ plan: RoomPlan) {
        for column in plan.shelfColumns {
            let block = SKSpriteNode(
                color: Palette.counter,
                size: CGSize(width: layout.tileSize, height: layout.tileSize * 1.25)
            )
            block.anchorPoint = .zero
            block.position = layout.point(of: RoomTile(column: column, row: plan.counterRow))
            block.zPosition = depth(ofBaseY: block.position.y, in: layout)
            addChild(block)
        }
    }

    private func addSeats(_ layout: RoomLayout, _ plan: RoomPlan) {
        for tile in plan.seatTiles {
            let seat = SKSpriteNode(
                color: Palette.seat,
                size: CGSize(width: layout.tileSize * 0.75, height: layout.tileSize * 0.75)
            )
            seat.anchorPoint = .zero
            seat.position = layout.snap(CGPoint(
                x: layout.point(of: tile).x + layout.tileSize * 0.125,
                y: layout.point(of: tile).y + layout.tileSize * 0.125
            ))
            seat.zPosition = depth(ofBaseY: layout.point(of: tile).y, in: layout)
            addChild(seat)
        }
    }

    private func addOven(_ layout: RoomLayout, _ plan: RoomPlan) -> SKSpriteNode {
        let oven: SKSpriteNode
        if let first = ovenFrames().first {
            oven = SKSpriteNode(texture: first)
            oven.size = CGSize(
                width: first.size().width * CGFloat(layout.scale),
                height: first.size().height * CGFloat(layout.scale)
            )
        } else {
            oven = SKSpriteNode(
                color: Palette.oven,
                size: CGSize(
                    width: layout.tileSize * CGFloat(plan.ovenColumns.count),
                    height: layout.tileSize * 3
                )
            )
        }
        oven.anchorPoint = .zero
        oven.position = layout.tileRect(column: plan.ovenColumns.lowerBound, row: plan.ovenRow).origin
        oven.zPosition = depth(ofBaseY: oven.position.y, in: layout)
        addChild(oven)
        return oven
    }

    private func addCase(_ layout: RoomLayout, _ plan: RoomPlan) -> CGRect {
        let names = PixelTexture.names(in: .bakery, prefix: "case_")
        let node: SKSpriteNode
        if let first = names.first {
            let texture = PixelTexture.named(first, in: .bakery)
            node = SKSpriteNode(texture: texture)
            node.size = CGSize(
                width: texture.size().width * CGFloat(layout.scale),
                height: texture.size().height * CGFloat(layout.scale)
            )
        } else {
            node = SKSpriteNode(
                color: Palette.counter,
                size: CGSize(width: layout.tileSize, height: layout.tileSize * 2)
            )
        }
        node.anchorPoint = .zero
        node.position = layout.point(of: RoomTile(column: plan.caseColumn, row: plan.counterRow))
        node.zPosition = depth(ofBaseY: node.position.y, in: layout)
        addChild(node)

        let base = layout.tileRect(column: plan.caseColumn, row: plan.counterRow)
        let end = layout.tileRect(column: plan.shelfColumns.upperBound, row: plan.counterRow)
        return CGRect(
            x: base.minX,
            y: base.minY,
            width: end.maxX - base.minX,
            height: layout.tileSize * 3
        )
    }

    private func makeBaker(_ layout: RoomLayout) -> SKSpriteNode {
        let baker: SKSpriteNode
        if let texture = frames(.idle, facing: .down).first {
            baker = SKSpriteNode(texture: texture)
            baker.size = CGSize(
                width: texture.size().width * CGFloat(layout.scale),
                height: texture.size().height * CGFloat(layout.scale)
            )
        } else {
            baker = SKSpriteNode(
                color: Palette.baker,
                size: CGSize(width: layout.tileSize, height: layout.tileSize * 2)
            )
        }
        baker.anchorPoint = .zero
        return baker
    }

    // MARK: - Rendering the model

    private func render() {
        guard let stage else { return }
        renderChrome(stage)
        setOvenRunning({ if case .baking = model.phase { true } else { false } }())
        renderShelf()
    }

    private func renderChrome(_ stage: Stage) {
        let timerText: String
        let tagText: String
        switch model.phase {
        case .baking(let seconds):
            let clamped = max(0, seconds)
            timerText = String(format: "%d:%02d", clamped / 60, clamped % 60)
            tagText = "baking…"
        case .delivering:
            timerText = ""
            tagText = "ready"
        case .idle:
            timerText = ""
            tagText = ""
        }
        setText(stage.timer, timerText, centeredOn: stage.timerCenter)
        setText(stage.tag, tagText, centeredOn: stage.tagCenter)
        setText(stage.coins, "\(model.coins)c", centeredOn: stage.coinsCenter)
    }

    private func setText(_ node: BitmapTextNode, _ text: String, centeredOn point: CGPoint) {
        guard node.text != text else { return }
        node.text = text
        node.place(centeredOn: point)
    }

    /// The oven is the primary "something is baking" signal (05, 14), so it
    /// runs exactly while the phase is `.baking` — completion, burn and cancel
    /// all stop it because they all leave that phase. It keeps animating under
    /// reduced motion: spec 13 says calmer, not state-blind.
    private func setOvenRunning(_ running: Bool) {
        guard let stage else { return }
        if running {
            guard stage.oven.action(forKey: "bake") == nil else { return }
            let frames = ovenFrames()
            let loop: SKAction
            if frames.count > 1 {
                loop = .animate(with: frames, timePerFrame: Pace.ovenFrameTime, resize: false, restore: false)
            } else {
                // Placeholder-first: the block still has to say "baking" from
                // across the room.
                loop = .sequence([
                    .colorize(with: Palette.ovenGlow, colorBlendFactor: 1, duration: 0.5),
                    .colorize(with: Palette.oven, colorBlendFactor: 1, duration: 0.5),
                ])
            }
            stage.oven.run(.repeatForever(loop), withKey: "bake")
        } else {
            stage.oven.removeAction(forKey: "bake")
            if let first = ovenFrames().first {
                stage.oven.texture = first
            } else {
                stage.oven.color = Palette.oven
            }
        }
    }

    private func renderShelf() {
        guard let stage else { return }
        var visible = model.treats
        if case .delivering = model.phase, !placedDeliveredTreat, !visible.isEmpty {
            // The store already holds the finished bake (02); the room shows it
            // only once the baker has carried it over (05, 08).
            visible.removeLast()
        }
        let slots = Array(stage.plan.shelfColumns)
        let shown = Array(visible.prefix(slots.count))
        guard shown != renderedShelf else { return }
        renderedShelf = shown

        stage.shelf.removeAllChildren()
        for (index, recipe) in shown.enumerated() {
            let tile = RoomTile(column: slots[index], row: stage.plan.counterRow)
            let treat = treatSprite(recipe, layout: stage.layout)
            treat.position = stage.layout.snap(CGPoint(
                x: stage.layout.point(of: tile).x,
                y: stage.layout.point(of: tile).y + stage.layout.tileSize * 0.25
            ))
            treat.zPosition = depth(ofBaseY: stage.layout.point(of: tile).y, in: stage.layout) + 1
            stage.shelf.addChild(treat)
        }
    }

    private func treatSprite(_ recipe: RecipeID, layout: RoomLayout) -> SKSpriteNode {
        let name = RecipeCatalog.recipe(for: recipe).spriteName
        let sprite: SKSpriteNode
        if PixelTexture.names(in: .treats, prefix: name).isEmpty {
            sprite = SKSpriteNode(
                color: Palette.treat,
                size: CGSize(width: layout.tileSize / 2, height: layout.tileSize / 2)
            )
        } else {
            let texture = PixelTexture.named(name, in: .treats)
            sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(
                width: texture.size().width * CGFloat(layout.scale),
                height: texture.size().height * CGFloat(layout.scale)
            )
        }
        sprite.anchorPoint = .zero
        return sprite
    }

    // MARK: - The baker

    private func enter(_ next: Activity) {
        guard let stage else { return }
        // Cancelling first is the interruptibility rule: nothing below waits
        // for an in-flight animation, and a removed action never fires its
        // completion, so a superseded choreography cannot come back to life.
        stage.baker.removeAllActions()
        dropCarriedTreat()
        stage.baker.position = stage.layout.snap(stage.baker.position)
        activity = next

        switch next {
        case .resting:
            walk(to: stage.plan.restTile) {
                self.playLoop(.idle, facing: .down)
            }
        case .walkingToStation:
            walk(to: stage.plan.stationTile) {
                self.enter(.working)
            }
        case .working:
            playWorkLoop()
        case .delivering:
            placedDeliveredTreat = false
            renderShelf()
            deliver()
        case .celebrating:
            celebrate()
        }
    }

    /// Movement between anchors: the authored route, walked in whole art
    /// pixels (01) with the walk cycle keyed per leg. Under reduced motion the
    /// state change happens without the travel.
    private func walk(to tile: RoomTile, then arrive: @escaping @MainActor () -> Void) {
        guard let stage else { return }
        let baker = stage.baker
        let layout = stage.layout
        let destination = layout.point(of: tile)

        if model.reduceMotion {
            baker.run(.sequence([
                .run { baker.position = destination },
                .wait(forDuration: 0.3),
                .run { arrive() },
            ]), withKey: "move")
            return
        }

        let route = stage.plan.route(from: layout.nearestTile(to: baker.position), to: tile)
        var cursor = layout.snap(baker.position)
        var actions: [SKAction] = []
        for waypoint in route {
            let target = layout.point(of: waypoint)
            guard target != cursor else { continue }
            let facing = Facing(from: cursor, to: target)
            actions.append(.run { self.playLoop(.walk, facing: facing) })
            actions.append(layout.walk(
                from: cursor,
                to: target,
                artPixelsPerSecond: Pace.walkArtPixelsPerSecond
            ))
            cursor = target
        }
        actions.append(.run {
            baker.removeAction(forKey: "cycle")
            arrive()
        })
        baker.run(.sequence(actions), withKey: "move")
    }

    /// The pack has no baking animation (14), so the station loop is assembled
    /// from pick up and lift at the counter, with idle beats between so an hour
    /// of it bears watching — the oven carries the real signal.
    private func playWorkLoop() {
        guard let baker = stage?.baker else { return }
        baker.removeAction(forKey: "cycle")
        let idleFrames = frames(.idle, facing: .up)
        guard let first = idleFrames.first else { return }
        baker.texture = first
        guard !model.reduceMotion, idleFrames.count > 1 else { return }

        let idle = SKAction.animate(
            with: idleFrames, timePerFrame: Pace.idleFrameTime, resize: false, restore: false
        )
        baker.run(.repeatForever(.sequence([
            idle,
            animateOnce(.pickup, facing: .up),
            idle, idle,
            animateOnce(.lift, facing: .up),
            idle,
        ])), withKey: "cycle")
    }

    /// The completion payoff, straight from spec 05's table: pick up at the
    /// oven, carry the treat across the room, place it. Never shortcut into
    /// the treat popping into existence.
    private func deliver() {
        guard let stage else { return }
        walk(to: stage.plan.stationTile) {
            stage.baker.run(.sequence([
                .run { self.face(.up) },
                self.animateOnce(.pickup, facing: .up),
                .run { self.pickUpTreat() },
                .wait(forDuration: 0.15),
                .run {
                    self.walk(to: stage.plan.deliverTile) {
                        self.face(.up)
                        self.placeTreat()
                        self.enter(.celebrating)
                    }
                },
            ]), withKey: "act")
        }
    }

    private func celebrate() {
        guard let stage else { return }
        stage.baker.run(.sequence([
            .run { self.face(.down) },
            animateOnce(.lift, facing: .down),
            .wait(forDuration: 0.2),
            .run {
                self.onEvent?(.deliveryFinished)
                self.enter(.resting)
            },
        ]), withKey: "act")
    }

    private func pickUpTreat() {
        guard let stage, case .delivering(let recipe) = model.phase else { return }
        let treat = treatSprite(recipe, layout: stage.layout)
        treat.position = stage.layout.snap(CGPoint(x: 0, y: stage.layout.tileSize * 1.25))
        treat.zPosition = 1
        stage.baker.addChild(treat)
        carried = treat
    }

    private func placeTreat() {
        dropCarriedTreat()
        placedDeliveredTreat = true
        renderShelf()
        onEvent?(.treatPlaced)
    }

    private func dropCarriedTreat() {
        carried?.removeFromParent()
        carried = nil
    }

    // MARK: - Animation plumbing

    private enum Cycle: String {
        case idle, walk, pickup, lift
    }

    private func frames(_ cycle: Cycle, facing: Facing) -> [SKTexture] {
        PixelTexture.names(in: .baker, prefix: "baker_\(cycle.rawValue)_\(facing.rawValue)_")
            .map { PixelTexture.named($0, in: .baker) }
    }

    private func ovenFrames() -> [SKTexture] {
        PixelTexture.names(in: .bakery, prefix: "oven_")
            .filter { !$0.hasPrefix("oven_front") }
            .map { PixelTexture.named($0, in: .bakery) }
    }

    private func playLoop(_ cycle: Cycle, facing: Facing) {
        guard let baker = stage?.baker else { return }
        baker.removeAction(forKey: "cycle")
        let textures = frames(cycle, facing: facing)
        guard let first = textures.first else { return }
        baker.texture = first
        guard textures.count > 1, !model.reduceMotion else { return }
        baker.run(.repeatForever(.animate(
            with: textures,
            timePerFrame: cycle == .idle ? Pace.idleFrameTime : Pace.walkFrameTime,
            resize: false,
            restore: false
        )), withKey: "cycle")
    }

    private func face(_ facing: Facing) {
        guard let baker = stage?.baker else { return }
        baker.removeAction(forKey: "cycle")
        if let first = frames(.idle, facing: facing).first {
            baker.texture = first
        }
    }

    private func animateOnce(_ cycle: Cycle, facing: Facing) -> SKAction {
        let textures = frames(cycle, facing: facing)
        guard textures.count > 1, !model.reduceMotion else { return .wait(forDuration: 0.3) }
        return .animate(with: textures, timePerFrame: Pace.workFrameTime, resize: false, restore: false)
    }

    private func depth(ofBaseY y: CGFloat, in layout: RoomLayout) -> CGFloat {
        (layout.roomFrame.maxY - y) / CGFloat(layout.scale)
    }
}

/// App state → target sprite state, pure, so the spec's "any state enterable
/// from any state" rule is a testable mapping rather than a property of
/// whatever completion handlers happen to be in flight.
enum BakerDirector {
    /// nil means the current activity already serves the phase and is left to
    /// run — including the internal transitions (arrival, placement, the
    /// celebrate settling to rest) that the scene advances by itself.
    static func target(
        for phase: BakeryScene.Model.Phase,
        current: BakeryScene.Activity
    ) -> BakeryScene.Activity? {
        switch phase {
        case .baking:
            current == .walkingToStation || current == .working ? nil : .walkingToStation
        case .delivering:
            current == .delivering || current == .celebrating ? nil : .delivering
        case .idle:
            // A celebrate beat finishes: it settles to resting by itself, and
            // cutting it would eat the payoff at the exact moment the app
            // layer acknowledges the outcome.
            current == .resting || current == .celebrating ? nil : .resting
        }
    }
}
