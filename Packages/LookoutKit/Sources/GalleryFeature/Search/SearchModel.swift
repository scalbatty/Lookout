import Domain
import Observation

/// Turns what the user types into search results.
///
/// Waits for typing to pause before searching, ignores changes that don't
/// change the query (case-sensitive, surrounding whitespace trimmed), and
/// gives each query its own `PhotoGridModel`, so results from two queries
/// can never mix in one grid.
@MainActor
@Observable
public final class SearchModel {
    /// The query being shown, or `nil` when the field is empty or blank.
    public private(set) var query: SearchQuery?
    /// The grid for `query`; `nil` when not searching.
    public private(set) var results: PhotoGridModel?

    private let repository: any PhotoRepository
    private let typingPause: Duration

    public init(repository: any PhotoRepository, typingPause: Duration = .milliseconds(400)) {
        self.repository = repository
        self.typingPause = typingPause
    }

    /// Call with the field's text on every change, cancelling the previous
    /// call (`.task(id:)` does this). Searches only once typing pauses.
    public func update(for text: String) async {
        // Clearing the field returns to the feed at once, without waiting.
        guard let newQuery = SearchQuery(text) else {
            show(nil)
            return
        }
        guard newQuery != query else { return }
        try? await Task.sleep(for: typingPause)
        // Cancelled: the user kept typing, or the screen went away.
        guard !Task.isCancelled else { return }
        show(newQuery)
    }

    private func show(_ newQuery: SearchQuery?) {
        guard newQuery != query else { return }
        results?.cancel()
        query = newQuery
        results = newQuery.map { query in
            PhotoGridModel { [repository] page in
                try await repository.searchPhotos(matching: query, page: page)
            }
        }
    }
}
