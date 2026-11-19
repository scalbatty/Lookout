/// Failures a photo source can report, independent of its transport.
/// Each case maps to a distinct message or action in the UI.
public enum DomainError: Error, Equatable, Sendable {
    /// No network connection.
    case offline
    /// The source refused the request because of its request quota.
    case rateLimited
    /// The source rejected our credentials (e.g. an invalid access key).
    case unauthorized
    /// The source answered with a status we don't handle specifically
    /// (server failures, or unexpected client errors).
    case unexpectedStatus(Int)
    /// The source answered with something we couldn't understand.
    case invalidResponse
}
