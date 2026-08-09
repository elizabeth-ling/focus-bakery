import Foundation
import OSLog

/// Fail-soft JSON persistence for one slice of app state.
///
/// Spec 02 requires that a corrupt or missing store falls back to a clean
/// first-run value rather than crashing, and that unreadable display-case data
/// never takes the recipe book with it. One file per slice is what bounds the
/// blast radius: each slice fails alone.
struct JSONFileStore<Value: Codable & Sendable>: Sendable {
    private static var logger: Logger {
        Logger(subsystem: "com.focusbakery.FocusBakery", category: "persistence")
    }

    let url: URL
    private let fallback: @Sendable () -> Value

    init(url: URL, fallback: @escaping @Sendable () -> Value) {
        self.url = url
        self.fallback = fallback
    }

    func load() -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else { return fallback() }
        do {
            return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
        } catch {
            // Reported rather than swallowed: a silently reset display case is
            // very hard to tell apart from a correct daily reset.
            Self.logger.error("Unreadable store at \(url.lastPathComponent, privacy: .public), falling back to a clean value: \(error.localizedDescription, privacy: .public)")
            return fallback()
        }
    }

    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            Self.logger.error("Failed to write \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum StoreLocation {
    /// Application Support, not Documents (these are not user-facing files) and
    /// not Caches (the system may purge those).
    static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return base.appending(path: "FocusBakery", directoryHint: .isDirectory)
    }
}
