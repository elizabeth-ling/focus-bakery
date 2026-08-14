import Foundation

/// The soft-commitment rule: leave your bake and it burns.
///
/// v1 is soft commitment only — no blocker, no Family Controls, no entitlement
/// (spec 00). This constant is the entire teeth of the mechanic.
enum BurnPolicy {
    /// How long the app may sit in the background mid-bake before the bake is
    /// abandoned.
    ///
    /// Long enough that a mis-swipe or a glance at a banner does not destroy
    /// fifty minutes of work, short enough that it cannot be spent doing
    /// something else. Only `.background` starts this window: an incoming call,
    /// Control Centre or the app switcher leave the scene `.inactive`, and the
    /// user has not gone anywhere.
    static let backgroundGrace: TimeInterval = 30
}

/// What the persisted session amounts to at a given instant.
enum SessionResolution: Equatable, Sendable {
    case idle
    case baking(remaining: TimeInterval)
    case completed
    case burned
}

extension SessionState {
    /// Resolution as a pure function of (persisted session, current date).
    ///
    /// Spec 03 requires exactly this shape, and it is what lets every wall-clock
    /// case — backgrounding, being killed, midnight, a timezone change, a clock
    /// dragged backwards — be driven in a test without sleeping.
    func resolution(at now: Date) -> SessionResolution {
        guard let session = active, session.outcome == .inProgress else { return .idle }

        if let leftAt = leftForegroundAt {
            let burnsAt = leftAt.addingTimeInterval(BurnPolicy.backgroundGrace)
            // Only an absence that outlasts the bake destroys it. Once `endDate`
            // has passed there is nothing left to abandon, so coming back to
            // collect a finished bake is never a burn.
            if burnsAt < session.endDate, burnsAt <= now { return .burned }
        }

        // Strictly earlier, so a clock dragged backwards keeps the bake running
        // rather than awarding an end that has not genuinely arrived.
        guard now < session.endDate else { return .completed }
        return .baking(remaining: session.endDate.timeIntervalSince(now))
    }
}
