import Foundation
import Testing
@testable import FocusBakery

/// Spec 03's edge-case table, driven against the pure resolution function.
@Suite("Session resolution")
struct SessionResolutionTests {
    private let start = instant(2026, 8, 14, 9)
    private let duration = 25

    private func state(leftAt: Date? = nil) -> SessionState {
        SessionState(
            active: BakeSession(
                recipeID: .chocolateChipCookie,
                startDate: start,
                durationMinutes: duration
            ),
            leftForegroundAt: leftAt
        )
    }

    private var endDate: Date {
        start.addingTimeInterval(TimeInterval(duration) * 60)
    }

    @Test("Remaining time is recomputed from the stored end date, never counted")
    func remainingComesFromTheEndDate() {
        let session = state()

        #expect(session.resolution(at: start) == .baking(remaining: 1500))
        #expect(session.resolution(at: start.addingTimeInterval(600)) == .baking(remaining: 900))
        #expect(session.resolution(at: endDate.addingTimeInterval(-1)) == .baking(remaining: 1))
    }

    @Test("The bake completes once the end date has passed")
    func completesAtTheEndDate() {
        #expect(state().resolution(at: endDate) == .completed)
        #expect(state().resolution(at: endDate.addingTimeInterval(3600)) == .completed)
    }

    @Test("A clock dragged backwards never awards an end that has not arrived")
    func clockMovedBackwardsDoesNotComplete() {
        // Elapsed is negative here: "now" precedes the moment the bake started.
        let resolution = state().resolution(at: start.addingTimeInterval(-1800))

        #expect(resolution == .baking(remaining: 3300))
    }

    @Test("Returning inside the grace keeps the bake")
    func returningInsideTheGraceKeepsTheBake() {
        let leftAt = start.addingTimeInterval(300)
        let returned = leftAt.addingTimeInterval(BurnPolicy.backgroundGrace - 1)

        #expect(state(leftAt: leftAt).resolution(at: returned) == .baking(remaining: 1171))
    }

    @Test("Staying away past the grace burns the bake")
    func outstayingTheGraceBurns() {
        let leftAt = start.addingTimeInterval(300)
        let returned = leftAt.addingTimeInterval(BurnPolicy.backgroundGrace + 1)

        #expect(state(leftAt: leftAt).resolution(at: returned) == .burned)
    }

    @Test("Leaving mid-bake and returning after the end date is still a burn")
    func leavingMidBakeBurnsEvenIfTheEndPasses() {
        let leftAt = start.addingTimeInterval(60)

        #expect(state(leftAt: leftAt).resolution(at: endDate.addingTimeInterval(3600)) == .burned)
    }

    @Test("Leaving inside the final seconds completes: there was nothing left to abandon")
    func leavingWithLessThanTheGraceLeftCompletes() {
        let leftAt = endDate.addingTimeInterval(-(BurnPolicy.backgroundGrace - 5))

        #expect(state(leftAt: leftAt).resolution(at: leftAt) == .baking(remaining: 25))
        #expect(state(leftAt: leftAt).resolution(at: endDate.addingTimeInterval(3600)) == .completed)
    }

    @Test("Leaving after the bake finished never burns it")
    func leavingAfterTheEndNeverBurns() {
        let leftAt = endDate.addingTimeInterval(60)

        #expect(state(leftAt: leftAt).resolution(at: leftAt.addingTimeInterval(3600)) == .completed)
    }

    @Test("An empty slot resolves to idle")
    func noSessionIsIdle() {
        #expect(SessionState().resolution(at: start) == .idle)
    }
}
