import Domain
import Observation

/// Drives a photo grid: decides when to load the next page and owns that work.
///
/// The same model serves the editorial feed and search results; only the
/// `loadPage` function it is created with differs.
@MainActor
@Observable
public final class PhotoGridModel {
    /// What the grid should show right now.
    public var state: PhotoGridState {
        let items = paginator.items
        switch paginator.phase {
        case .idle, .loadingFirstPage:
            return .loading
        case .failed(let error, isFirstPage: true):
            return .failed(PhotoGridError(error))
        case .loaded where items.isEmpty:
            return .empty
        case .loaded(hasMore: true):
            return .photos(items, footer: .none)
        case .loaded(hasMore: false):
            return .photos(items, footer: .end)
        case .loadingNextPage:
            return .photos(items, footer: .loading)
        case .failed(let error, isFirstPage: false):
            return .photos(items, footer: .failed(PhotoGridError(error)))
        }
    }

    private let paginator: Paginator
    /// How many items before the end a visible cell starts loading the next page.
    private let prefetchDistance: Int
    /// The page load in flight, if any. Owned here (not by a view) so it
    /// survives views disappearing, e.g. while a photo is shown full screen.
    @ObservationIgnored private(set) var loadTask: Task<Void, Never>?

    public init(
        prefetchDistance: Int = 10,
        loadPage: @escaping @Sendable (Int) async throws -> Page<Photo>
    ) {
        self.prefetchDistance = prefetchDistance
        self.paginator = Paginator(loadPage: loadPage)
    }

    /// Loads the first page, if nothing was requested yet.
    public func start() {
        guard paginator.phase == .idle else { return }
        load()
    }

    /// Called when a cell becomes visible. Loads the next page when the cell
    /// is close to the end. Failed loads are not retried automatically, to
    /// spare the request quota: the user retries explicitly.
    public func itemAppeared(_ id: PhotoID) {
        guard paginator.phase == .loaded(hasMore: true),
              paginator.items.suffix(prefetchDistance).contains(where: { $0.id == id })
        else { return }
        load()
    }

    /// Called when the row below the photos becomes visible. Covers what
    /// `itemAppeared` can't: the end of the list already on screen when a
    /// page finishes (large screens, or a page that only held duplicates).
    public func footerAppeared() {
        guard paginator.phase == .loaded(hasMore: true) else { return }
        load()
    }

    public func retry() {
        guard case .failed = paginator.phase else { return }
        load()
    }

    /// Stops the page load in flight, e.g. when this grid is replaced.
    public func cancel() {
        loadTask?.cancel()
    }

    private func load() {
        guard loadTask == nil else { return }
        loadTask = Task {
            await paginator.loadNextPage()
            loadTask = nil
        }
    }
}
