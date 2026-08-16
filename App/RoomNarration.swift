import Foundation

/// What the room says to VoiceOver.
///
/// Spec 13's sharpest point: **the bitmap text is not text**. The countdown, the
/// ♦ counts and every fixture in the room are `SKNode`s (01, 05), so nothing on
/// the main screen exists to the system unless it is written out somewhere. This
/// is that somewhere — one pure function per fact, so what the app says can be
/// read in a test rather than only off a device with VoiceOver running.
///
/// It sits beside `BakerDirector` in kind: a pure mapping out of the phase the
/// app layer already owns, so the scene is not asked to describe itself.
enum RoomNarration {
    /// The countdown, spelled rather than shown.
    ///
    /// Not the sprite string: "24:30" is read as punctuation or as a time of
    /// day, and neither is what it means. The unit style is also localised,
    /// which a hand-built "24 minutes" would not be.
    static func timeRemaining(seconds: Int) -> String {
        Duration.seconds(max(0, seconds)).formatted(
            .units(allowed: [.minutes, .seconds], width: .wide)
        )
    }

    /// The oven is the room's primary "something is baking" signal (05, 14), and
    /// it is where the remaining time is reachable — the countdown floats over
    /// open floor, but the thing it is counting down is this.
    static func oven(_ phase: BakeryScene.Model.Phase) -> String {
        switch phase {
        case .idle:
            "Cold"
        case .baking(let seconds):
            "Baking, \(timeRemaining(seconds: seconds)) left"
        case .delivering:
            "Done baking"
        }
    }

    /// Spec 13 names this one outright: "the baker is working" is state the
    /// sighted user reads at a glance and a VoiceOver user otherwise cannot
    /// reach at all.
    static func baker(_ phase: BakeryScene.Model.Phase) -> String {
        switch phase {
        case .idle:
            "Resting. Nothing is baking."
        case .baking:
            "Working at the oven."
        case .delivering(let recipeID):
            "Carrying a \(RecipeCatalog.recipe(for: recipeID).name) to the display case."
        }
    }

    /// Never phrased as loss: an empty case is a bakery about to open (08, 11).
    static func displayCase(count: Int) -> String {
        switch count {
        case 0: "Empty, ready for today"
        case 1: "1 treat today"
        default: "\(count) treats today"
        }
    }
}
