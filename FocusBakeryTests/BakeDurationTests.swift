import Foundation
import Testing
@testable import FocusBakery

@Suite("Bake duration limits")
struct BakeDurationTests {
    @Test("The limits are coherent: a stepped range with the default inside it")
    func limitsAreCoherent() {
        #expect(BakeDuration.minimumMinutes < BakeDuration.maximumMinutes)
        #expect(BakeDuration.minimumMinutes % BakeDuration.stepMinutes == 0)
        #expect(BakeDuration.maximumMinutes % BakeDuration.stepMinutes == 0)
        #expect(BakeDuration.clamped(BakeDuration.defaultMinutes) == BakeDuration.defaultMinutes)
    }

    @Test("Clamping bounds the value and snaps it to the step grid")
    func clampingBoundsAndSnaps() {
        #expect(BakeDuration.clamped(0) == BakeDuration.minimumMinutes)
        #expect(BakeDuration.clamped(-30) == BakeDuration.minimumMinutes)
        #expect(BakeDuration.clamped(10_000) == BakeDuration.maximumMinutes)
        #expect(BakeDuration.clamped(27) == 25)
        #expect(BakeDuration.clamped(28) == 30)
        #expect(BakeDuration.clamped(25) == 25)
    }

    @Test("Every step from the minimum lands on a legal duration")
    func steppingStaysLegal() {
        var minutes = BakeDuration.minimumMinutes
        while minutes < BakeDuration.maximumMinutes {
            let next = BakeDuration.clamped(minutes + BakeDuration.stepMinutes)
            #expect(next == minutes + BakeDuration.stepMinutes)
            minutes = next
        }
        #expect(BakeDuration.clamped(minutes + BakeDuration.stepMinutes) == minutes)
    }

    @Test("The last-used duration and recipe are remembered, and hardened on the way out")
    func lastUsedIsRemembered() {
        let settings = Settings(defaults: makeTemporaryDefaults())

        #expect(settings.lastBakeDurationMinutes == BakeDuration.defaultMinutes)
        #expect(settings.lastBakeRecipeID == nil)

        settings.lastBakeDurationMinutes = 50
        settings.lastBakeRecipeID = .croissant
        #expect(settings.lastBakeDurationMinutes == 50)
        #expect(settings.lastBakeRecipeID == .croissant)

        // A stored value that has gone stale or absurd comes back legal.
        settings.lastBakeDurationMinutes = 7
        #expect(settings.lastBakeDurationMinutes == 5)
        settings.lastBakeDurationMinutes = 10_000
        #expect(settings.lastBakeDurationMinutes == BakeDuration.maximumMinutes)
    }
}
