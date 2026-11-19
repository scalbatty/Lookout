import Domain
import Foundation
import Testing
@testable import GalleryFeature

@MainActor
struct PhotoGridModelTests {
    @Test func startLoadsFirstPageOnce() async {
        let source = PageSource(pages: [ids("a", "b")])
        let model = PhotoGridModel(loadPage: source.load)

        model.start()
        await model.loadTask?.value
        model.start()

        #expect(model.state == .photos(photos("a", "b"), footer: .none))
        #expect(await source.requestedPages == [1])
    }

    @Test func cellNearTheEndLoadsNextPage() async {
        let source = PageSource(pages: [ids("a", "b", "c", "d", "e"), ids("f")])
        let model = PhotoGridModel(prefetchDistance: 2, loadPage: source.load)
        model.start()
        await model.loadTask?.value

        model.itemAppeared("d")
        await model.loadTask?.value

        #expect(await source.requestedPages == [1, 2])
        #expect(model.state == .photos(photos("a", "b", "c", "d", "e", "f"), footer: .none))
    }

    @Test func cellFarFromTheEndDoesNothing() async {
        let source = PageSource(pages: [ids("a", "b", "c", "d", "e")])
        let model = PhotoGridModel(prefetchDistance: 2, loadPage: source.load)
        model.start()
        await model.loadTask?.value

        model.itemAppeared("c")

        #expect(model.loadTask == nil)
        #expect(await source.requestedPages == [1])
    }

    @Test func footerAppearingLoadsNextPage() async {
        let source = PageSource(pages: [ids("a"), ids("b")])
        let model = PhotoGridModel(loadPage: source.load)
        model.start()
        await model.loadTask?.value

        model.footerAppeared()
        await model.loadTask?.value

        #expect(await source.requestedPages == [1, 2])
    }

    @Test func footerAppearingDuringALoadDoesNothing() async {
        let source = PageSource(pages: [ids("a")])
        let model = PhotoGridModel(loadPage: source.load)

        model.start()
        model.footerAppeared()
        await model.loadTask?.value

        #expect(await source.requestedPages == [1])
    }

    @Test func noLoadAfterLastPage() async {
        let source = PageSource(pages: [ids("a")], hasMore: false)
        let model = PhotoGridModel(loadPage: source.load)
        model.start()
        await model.loadTask?.value

        model.itemAppeared("a")

        #expect(model.loadTask == nil)
    }

    @Test func failureIsOnlyRetriedExplicitly() async {
        let source = PageSource(pages: [ids("a"), ids("b")], failingPages: [2])
        let model = PhotoGridModel(loadPage: source.load)
        model.start()
        await model.loadTask?.value
        model.itemAppeared("a")
        await model.loadTask?.value
        #expect(model.state == .photos(photos("a"), footer: .failed(PhotoGridError(.offline))))

        // Scrolling doesn't retry.
        model.itemAppeared("a")
        #expect(model.loadTask == nil)

        await source.stopFailing()
        model.retry()
        await model.loadTask?.value
        #expect(model.state == .photos(photos("a", "b"), footer: .none))
        #expect(await source.requestedPages == [1, 2, 2])
    }

    @Test func cancelStopsTheLoadWithoutFailing() async {
        let model = PhotoGridModel { _ in
            try await Task.sleep(for: .seconds(10))
            return Page(items: [], hasMore: false)
        }

        model.start()
        model.cancel()
        await model.loadTask?.value

        #expect(model.state == .loading)
        #expect(model.loadTask == nil)
    }
}

// MARK: - State table

@MainActor
struct PhotoGridStateTests {
    @Test func loadingBeforeAndDuringFirstPage() {
        let model = PhotoGridModel { _ in Page(items: [], hasMore: false) }
        #expect(model.state == .loading)
    }

    @Test func firstPageFailureIsFullScreen() async {
        let model = PhotoGridModel { _ in throw DomainError.offline }
        model.start()
        await model.loadTask?.value
        #expect(model.state == .failed(PhotoGridError(.offline)))
    }

    @Test func emptyResult() async {
        let model = PhotoGridModel { _ in Page(items: [], hasMore: false) }
        model.start()
        await model.loadTask?.value
        #expect(model.state == .empty)
    }

    @Test func lastPageShowsEnd() async {
        let source = PageSource(pages: [ids("a")], hasMore: false)
        let model = PhotoGridModel(loadPage: source.load)
        model.start()
        await model.loadTask?.value
        #expect(model.state == .photos(photos("a"), footer: .end))
    }
}

// MARK: - Error presentation

struct PhotoGridErrorTests {
    @Test(arguments: [
        (DomainError.offline, "grid.error.offline", true),
        (.rateLimited, "grid.error.rateLimited", true),
        (.unauthorized, "grid.error.unauthorized", false),
        (.unexpectedStatus(500), "grid.error.generic", true),
        (.invalidResponse, "grid.error.generic", true),
    ])
    func mapsDomainErrors(error: DomainError, key: String, isRetryable: Bool) {
        let presented = PhotoGridError(error)
        #expect(presented.message.key == key)
        #expect(presented.isRetryable == isRetryable)
    }

    @Test func messagesResolveFromTheModuleCatalog() {
        var message = PhotoGridError(.offline).message
        message.locale = Locale(identifier: "en")
        #expect(String(localized: message) == "You're offline. Check your connection and try again.")
    }
}

// MARK: - Helpers

private func ids(_ ids: PhotoID...) -> [PhotoID] { ids }

private func photo(_ id: PhotoID) -> Photo {
    Photo(id: id, caption: nil, width: 1, height: 1, variants: [])
}

private func photos(_ ids: PhotoID...) -> [Photo] { ids.map(photo) }

/// Serves fixed pages of photos and records which pages were requested.
private actor PageSource {
    private let pages: [[PhotoID]]
    private let hasMore: Bool
    private var failingPages: Set<Int>
    private(set) var requestedPages: [Int] = []

    init(pages: [[PhotoID]], hasMore: Bool = true, failingPages: Set<Int> = []) {
        self.pages = pages
        self.hasMore = hasMore
        self.failingPages = failingPages
    }

    func stopFailing() { failingPages = [] }

    func load(_ page: Int) async throws -> Page<Photo> {
        requestedPages.append(page)
        if failingPages.contains(page) { throw DomainError.offline }
        return Page(items: pages[page - 1].map(photo), hasMore: hasMore)
    }
}
