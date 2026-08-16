import Testing
@testable import FocusBakery

/// Spec 13's VoiceOver criterion, made checkable: the room is sprites, so what
/// it says is a string the app produces rather than something the system can
/// read off the screen. Every fact the criterion names is asserted here.
@Suite("Room narration")
struct RoomNarrationTests {
    @Test("The countdown is spoken as units, not as the sprite string")
    func theCountdownIsSpelled() {
        // Never "24:30" — a colon is read as punctuation or as a time of day.
        #expect(!RoomNarration.timeRemaining(seconds: 1_470).contains(":"))
        #expect(RoomNarration.timeRemaining(seconds: 1_470).contains("24"))
        #expect(RoomNarration.timeRemaining(seconds: 1_470).contains("30"))
        // Whole minutes still say the minutes rather than falling to seconds.
        #expect(RoomNarration.timeRemaining(seconds: 300).contains("5"))
        // A bake the display tick has already run past says nothing absurd.
        #expect(!RoomNarration.timeRemaining(seconds: -5).contains("-"))
    }

    @Test("Every phase says what the oven and the baker are doing")
    func everyPhaseIsDescribed() {
        let phases: [BakeryScene.Model.Phase] = [
            .idle,
            .baking(secondsRemaining: 1_470),
            .delivering(.chocolateChipCookie),
        ]
        for phase in phases {
            #expect(!RoomNarration.oven(phase).isEmpty, "\(phase) leaves the oven silent")
            #expect(!RoomNarration.baker(phase).isEmpty, "\(phase) leaves the baker silent")
        }

        // The one fact the criterion names by hand: remaining time is reachable,
        // and it is reachable from the fixture that is doing the baking.
        #expect(RoomNarration.oven(.baking(secondsRemaining: 1_470)).contains(
            RoomNarration.timeRemaining(seconds: 1_470)
        ))
        // An idle room is not a broken one: it says so rather than saying
        // nothing, which is what a missing element would amount to.
        #expect(RoomNarration.oven(.idle) == "Cold")

        // Mid-delivery the treat is named, because that is what a sighted user
        // can see in the baker's hands.
        #expect(RoomNarration.baker(.delivering(.cake)).contains("Celebration Cake"))
    }

    /// Spec 08's empty state, which is also spec 11's rule: the daily reset is
    /// never framed to the user as something lost.
    @Test("The case counts up and never reads as a loss")
    func theCaseIsNeverPhrasedAsLoss() {
        #expect(RoomNarration.displayCase(count: 0) == "Empty, ready for today")
        #expect(RoomNarration.displayCase(count: 1) == "1 treat today")
        #expect(RoomNarration.displayCase(count: 12) == "12 treats today")
    }
}
