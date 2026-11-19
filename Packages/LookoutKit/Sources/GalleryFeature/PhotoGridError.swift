import Domain
import Foundation

/// An error as the grid presents it: a user-facing message, and whether
/// retrying can help.
public struct PhotoGridError: Equatable, Sendable {
    public let message: LocalizedStringResource
    public let isRetryable: Bool

    init(_ error: DomainError) {
        switch error {
        case .offline:
            message = Self.text("grid.error.offline")
            isRetryable = true
        case .rateLimited:
            message = Self.text("grid.error.rateLimited")
            isRetryable = true
        case .unauthorized:
            // A configuration problem: retrying can't fix it.
            message = Self.text("grid.error.unauthorized")
            isRetryable = false
        case .unexpectedStatus, .invalidResponse:
            message = Self.text("grid.error.generic")
            isRetryable = true
        }
    }

    private static func text(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
