import Foundation

struct Wallet: Codable, Hashable, Sendable {
    private(set) var coinBalance: Int = 0

    mutating func earn(_ amount: Int) {
        guard amount > 0 else { return }
        coinBalance += amount
    }

    /// Leaves the balance untouched and reports failure when funds are short.
    /// Spec 07 requires that the balance can never go negative.
    @discardableResult
    mutating func spend(_ amount: Int) -> Bool {
        guard amount >= 0, coinBalance >= amount else { return false }
        coinBalance -= amount
        return true
    }
}
