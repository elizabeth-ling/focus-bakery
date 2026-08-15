import Foundation

/// The input-layer bounds on a bake's duration.
///
/// Spec 03 places the constraint here, at the input, and spec 10 is the input:
/// the timer never receives a duration these limits did not pass. These are
/// interaction numbers, not economy numbers, which is why they do not live in
/// `Economy` — the earn curve prices whatever minutes arrive.
enum BakeDuration {
    /// Below five minutes a bake is a tap, not a commitment, and the burn
    /// mechanic has nothing to protect.
    static let minimumMinutes = 5
    /// Two hours. Long enough for a deep session; past it, one bake stops
    /// being one sitting.
    static let maximumMinutes = 120
    static let stepMinutes = 5
    static let defaultMinutes = 25

    /// Snaps to the step grid and clamps to the bounds, so a remembered or
    /// corrupt value costs the user a wrong-but-valid duration, never an
    /// absurd one (the `TimeOfDay` precedent).
    static func clamped(_ minutes: Int) -> Int {
        let snapped = Int((Double(minutes) / Double(stepMinutes)).rounded()) * stepMinutes
        return min(max(snapped, minimumMinutes), maximumMinutes)
    }
}
