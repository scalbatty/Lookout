import Observation

/// Loads a list of photos page by page and tracks where loading stands.
///
/// It doesn't know whether pages come from a feed or a search: it is given a
/// `loadPage` function and calls it with 1-based page numbers, one at a time.
@MainActor
@Observable
public final class Paginator {
    public enum Phase: Equatable, Sendable {
        /// Nothing requested yet.
        case idle
        case loadingFirstPage
        case loadingNextPage
        /// At least one page loaded. `hasMore == false` means the end was reached.
        case loaded(hasMore: Bool)
        /// The last request failed. Calling `loadNextPage()` retries the same page.
        case failed(DomainError, isFirstPage: Bool)
    }

    /// Every photo loaded so far, in order.
    public private(set) var items: [Photo] = []
    public private(set) var phase: Phase = .idle

    private var nextPage = 1
    private let loadPage: @Sendable (Int) async throws -> Page<Photo>

    public init(loadPage: @escaping @Sendable (Int) async throws -> Page<Photo>) {
        self.loadPage = loadPage
    }

    /// Loads the next page, or retries the one that failed.
    /// Does nothing while a load is in flight or after the last page.
    public func loadNextPage() async {
        let previousPhase = phase
        switch phase {
        case .idle, .loaded(hasMore: true), .failed:
            break
        case .loadingFirstPage, .loadingNextPage, .loaded(hasMore: false):
            return
        }

        let pageToLoad = nextPage
        phase = pageToLoad == 1 ? .loadingFirstPage : .loadingNextPage

        do {
            let result = try await loadPage(pageToLoad)
            items.append(contentsOf: result.items)
            nextPage += 1
            phase = .loaded(hasMore: result.hasMore)
        } catch is CancellationError {
            // Not a failure: whoever cancelled can ask again later.
            phase = previousPhase
        } catch {
            let domainError = error as? DomainError ?? .invalidResponse
            phase = .failed(domainError, isFirstPage: pageToLoad == 1)
        }
    }
}
