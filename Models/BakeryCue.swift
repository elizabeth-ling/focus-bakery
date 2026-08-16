import Foundation

/// Every sound and haptic the app makes, and the single place that decides
/// which is which.
///
/// Closed and pure on purpose. The hard part of spec 12 is restraint — haptics
/// on every tap "becomes noise and drains the effect where it matters" — and
/// restraint is only inspectable if the whole vocabulary fits on one screen. A
/// feeling the app wants to give and cannot name here has not been thought
/// about yet.
///
/// Spec 12's table lists a coin award and a treat landing as ticks of their
/// own. Both are folded into `completion`: coins are only ever earned by a bake
/// finishing (07), and the treat landing *is* the instant the completion cue is
/// defined to fire on (05). Three cues inside one second is the noise the
/// restraint rule is about.
enum BakeryCue: String, CaseIterable, Sendable {
    /// The payoff: the treat reaching the case at the end of the deliver walk
    /// (05), or the alert breaking the news of a bake that finished while the
    /// app was away (03).
    case completion
    /// A bake lost — the grace outstayed, or thrown out deliberately (03).
    case burned
    /// Turning a page of the recipe book, and stepping the duration (10).
    case step
    /// A recipe bought (07).
    case purchase

    /// What the app asks the Taptic Engine for, named by weight rather than by
    /// API so that this stays free of UIKit.
    enum Haptic: Sendable {
        case success
        case soft
        case light
    }

    /// The bundled file, without its extension. A cue whose file is absent is a
    /// silent cue and nothing worse (`FeedbackClient`), so the set can be
    /// re-recorded one sound at a time.
    var soundName: String { "cue_\(rawValue)" }

    var haptic: Haptic {
        switch self {
        // The one moment in the app worth a notification-weight haptic. Spec 12
        // asks for exactly one, and spending it anywhere else is precisely what
        // draining the effect looks like.
        case .completion: .success
        // Felt, not scolded. The mechanic works because the loss registers, so
        // the burn cannot be silent — but a warning buzz would make the app the
        // thing telling the user off. Soft is a thud, which is what a lost bake
        // is.
        case .burned: .soft
        case .step, .purchase: .light
        }
    }

    /// The bed under all of it, which is not a cue: nothing fires it, it simply
    /// runs for as long as the app is in front of the user with sound on.
    static let ambientSoundName = "bakery_ambient"
}
