import SpriteKit
import Testing
@testable import FocusBakery

/// Drives the scene headlessly: `apply(_:)` runs synchronously, so state entry,
/// the oven, the chrome and the shelf are all assertable without a view.
/// Actions do not advance without a presenting `SKView`, which is exactly why
/// the assertions accept either end of an internal transition — the walk
/// choreography's motion itself is covered by `GridMotionTests` and the device
/// pass.
@MainActor
@Suite("Bakery scene")
struct BakerySceneTests {
    private func makeScene(size: CGSize = CGSize(width: 393, height: 852)) -> BakeryScene {
        let scene = BakeryScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }

    private static let phases: [BakeryScene.Model.Phase] = [
        .idle,
        .baking(secondsRemaining: 90),
        .delivering(.chocolateChipCookie),
    ]

    private func activities(serving phase: BakeryScene.Model.Phase) -> Set<BakeryScene.Activity> {
        switch phase {
        case .idle: [.resting, .celebrating]
        case .baking: [.walkingToStation, .working]
        case .delivering: [.delivering, .celebrating]
        }
    }

    @Test("Any phase is enterable directly from any other")
    func anyPhaseFromAnyPhase() {
        for first in Self.phases {
            for second in Self.phases {
                let scene = makeScene()
                scene.apply(BakeryScene.Model(phase: first))
                scene.apply(BakeryScene.Model(phase: second))
                #expect(
                    activities(serving: second).contains(scene.activity),
                    "\(first) → \(second) left the baker \(scene.activity)"
                )
            }
        }
    }

    @Test("The director serves every phase from every activity")
    func directorServesEveryPair() {
        for phase in Self.phases {
            for current in BakeryScene.Activity.allCases {
                let target = BakerDirector.target(for: phase, current: current)
                let after = target ?? current
                #expect(
                    activities(serving: phase).contains(after),
                    "\(phase) from \(current) resolves to \(after)"
                )
            }
        }
    }

    @Test("Transitions leave the baker on the art-pixel grid")
    func bakerStaysOnTheGrid() throws {
        let scene = makeScene()
        let sequence: [BakeryScene.Model.Phase] = [
            .baking(secondsRemaining: 60),
            .delivering(.chocolateChipCookie),
            .idle,
            .baking(secondsRemaining: 30),
            .idle,
        ]
        for phase in sequence {
            scene.apply(BakeryScene.Model(phase: phase))
            let position = try #require(scene.bakerPosition)
            let step = CGFloat(RoomLayout(fitting: scene.size).scale)
            #expect(position.x.truncatingRemainder(dividingBy: step) == 0)
            #expect(position.y.truncatingRemainder(dividingBy: step) == 0)
        }
    }

    @Test("The oven runs during a bake and only during a bake")
    func ovenTracksTheSession() {
        let scene = makeScene()
        scene.apply(BakeryScene.Model(phase: .idle))
        #expect(!scene.isOvenRunning)

        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 300)))
        #expect(scene.isOvenRunning)
        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 299)))
        #expect(scene.isOvenRunning)

        // Completion leaves the baking phase, so the oven stops for the walk.
        scene.apply(BakeryScene.Model(phase: .delivering(.chocolateChipCookie)))
        #expect(!scene.isOvenRunning)

        // A burn or cancel goes straight to idle: also stops.
        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 60)))
        scene.apply(BakeryScene.Model(phase: .idle))
        #expect(!scene.isOvenRunning)
    }

    @Test("The countdown renders through the bitmap pipeline and clears with the bake")
    func timerFollowsThePhase() {
        let scene = makeScene()
        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 605)))
        #expect(scene.displayedTimer == "10:05")
        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 60)))
        #expect(scene.displayedTimer == "1:00")
        scene.apply(BakeryScene.Model(phase: .idle))
        #expect(scene.displayedTimer.isEmpty)
    }

    @Test("A delivered treat is withheld from the case until the baker places it")
    func deliveredTreatWaitsForTheWalk() {
        let scene = makeScene()
        scene.apply(BakeryScene.Model(
            phase: .baking(secondsRemaining: 1),
            treats: [.chocolateChipCookie]
        ))
        #expect(scene.displayedTreats == [TreatTally(recipeID: .chocolateChipCookie, count: 1)])

        // The store records the treat at completion (02); the walk has not
        // happened yet, so the case must still show the earlier count.
        scene.apply(BakeryScene.Model(
            phase: .delivering(.chocolateChipCookie),
            treats: [.chocolateChipCookie, .chocolateChipCookie]
        ))
        #expect(scene.displayedTreats == [TreatTally(recipeID: .chocolateChipCookie, count: 1)])

        // However the delivery ends — placed, interrupted, acknowledged — an
        // idle room shows everything the store says exists.
        scene.apply(BakeryScene.Model(
            phase: .idle,
            treats: [.chocolateChipCookie, .chocolateChipCookie]
        ))
        #expect(scene.displayedTreats == [TreatTally(recipeID: .chocolateChipCookie, count: 2)])
    }

    @Test("Repeated bakes of one recipe raise a quantity instead of taking slots")
    func repeatedBakesAccumulateAsQuantities() {
        let scene = makeScene()
        scene.apply(BakeryScene.Model(
            phase: .idle,
            treats: [.chocolateChipCookie, .croissant, .chocolateChipCookie, .chocolateChipCookie]
        ))
        // First-baked order, so the counter does not reshuffle as counts climb.
        #expect(scene.displayedTreats == [
            TreatTally(recipeID: .chocolateChipCookie, count: 3),
            TreatTally(recipeID: .croissant, count: 1),
        ])
        #expect(scene.visibleSlotCount == 2)
    }

    @Test("A burned bake adds nothing and sends the baker home")
    func burnedAddsNothingAndRests() {
        let scene = makeScene()
        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 300)))
        scene.apply(BakeryScene.Model(phase: .idle))
        #expect(scene.activity == .resting)
        #expect(scene.visibleSlotCount == 0)
        #expect(!scene.isOvenRunning)
    }

    @Test("A size change resettles the room instead of replaying transitions")
    func sizeChangeResettles() {
        let scene = makeScene()
        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 100)))
        scene.size = CGSize(width: 440, height: 956)
        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 99)))
        #expect(scene.activity == .working)
        #expect(scene.isOvenRunning)
        #expect(scene.displayedTimer == "1:39")
    }

    @Test("Reduced motion still reaches every state and still delivers")
    func reducedMotionReachesEveryState() {
        let scene = makeScene()
        scene.apply(BakeryScene.Model(phase: .baking(secondsRemaining: 60), reduceMotion: true))
        #expect(activities(serving: .baking(secondsRemaining: 60)).contains(scene.activity))
        #expect(scene.isOvenRunning)

        scene.apply(BakeryScene.Model(
            phase: .delivering(.cake),
            treats: [.cake],
            reduceMotion: true
        ))
        #expect(activities(serving: .delivering(.cake)).contains(scene.activity))

        scene.apply(BakeryScene.Model(phase: .idle, treats: [.cake], reduceMotion: true))
        #expect(activities(serving: .idle).contains(scene.activity))
        #expect(scene.visibleSlotCount == 1)
    }

    /// Spec 08's overflow criterion. Quantities are what make it hold: slots are
    /// spent per recipe, so a heavy day raises counts rather than reaching for
    /// shelf the room does not have.
    @Test("A heavy day neither drops a treat from the record nor spills sprites")
    func aHeavyDayStaysInsideTheCase() throws {
        let sizes = [
            CGSize(width: 393, height: 852),
            CGSize(width: 440, height: 956),
            CGSize(width: 320, height: 568),
        ]
        for size in sizes {
            let scene = makeScene(size: size)
            let plan = RoomPlan(fitting: RoomLayout(fitting: scene.size))
            // Forty bakes across the whole catalogue: far more than the shelf
            // has slots, and every recipe represented.
            let treats = (0..<40).map { RecipeID.allCases[$0 % RecipeID.allCases.count] }
            scene.apply(BakeryScene.Model(phase: .idle, treats: treats))

            #expect(scene.visibleSlotCount <= plan.shelfColumns.count)
            // Nothing silently vanishes: every recipe baked is still on show,
            // and the counts sum to the true tally.
            #expect(scene.displayedTreats.count == RecipeID.allCases.count)
            #expect(scene.displayedTreats.reduce(0) { $0 + $1.count } == treats.count)

            // And nothing spills into the room: every slot the case draws sits
            // within the case's own extent.
            let region = try #require(scene.caseRegion)
            for frame in scene.shelfSlotFrames {
                #expect(region.contains(frame), "\(frame) escaped \(region) at \(size)")
            }
        }
    }

    /// The invariant behind the criterion above: while the catalogue is smaller
    /// than the shelf, a full case is unreachable and no treat is ever hidden.
    /// If recipes ever outgrow the shelf this fails, which is the reminder to
    /// choose the stacked-case sprite spec 08 leaves open.
    @Test("The catalogue fits the shelf on every room the layout can resolve")
    func theCatalogueFitsTheShelf() {
        let sizes = [
            CGSize(width: 320, height: 568),
            CGSize(width: 393, height: 852),
            CGSize(width: 440, height: 956),
            CGSize(width: 1024, height: 1366),
        ]
        for size in sizes {
            let plan = RoomPlan(fitting: RoomLayout(fitting: size))
            #expect(RecipeID.allCases.count <= plan.shelfColumns.count, "\(size)")
        }
    }
}
