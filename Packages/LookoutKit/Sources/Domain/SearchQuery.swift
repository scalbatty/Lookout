import Foundation

/// A non-empty search query. Invalid input can't reach a photo source:
/// empty or whitespace-only text doesn't produce a query at all.
public struct SearchQuery: Hashable, Sendable {
    /// The query text, trimmed of surrounding whitespace.
    public let text: String

    /// Returns `nil` for empty or whitespace-only input.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        text = trimmed
    }
}
