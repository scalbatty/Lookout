import Foundation
import Testing
import Domain

@MainActor
struct PaginatorTests {
    // MARK: Loading pages

    @Test func startsIdleAndEmpty() {
        let paginator = Paginator { _ in Page(items: [], hasMore: false) }
        #expect(paginator.phase == .idle)
        #expect(paginator.items.isEmpty)
    }

    @Test func loadsFirstPage() async {
        let source = ScriptedPages([.success(page(["a", "b"], hasMore: true))])
        let paginator = Paginator(loadPage: source.load)

        await paginator.loadNextPage()

        #expect(await source.requestedPages == [1])
        #expect(paginator.items.map(\.id) == ["a", "b"])
        #expect(paginator.phase == .loaded(hasMore: true))
    }

    @Test func appendsFollowingPages() async {
        let source = ScriptedPages([
            .success(page(["a"], hasMore: true)),
            .success(page(["b"], hasMore: true)),
        ])
        let paginator = Paginator(loadPage: source.load)

        await paginator.loadNextPage()
        await paginator.loadNextPage()

        #expect(await source.requestedPages == [1, 2])
        #expect(paginator.items.map(\.id) == ["a", "b"])
    }

    @Test func stopsAfterLastPage() async {
        let source = ScriptedPages([.success(page(["a"], hasMore: false))])
        let paginator = Paginator(loadPage: source.load)

        await paginator.loadNextPage()
        await paginator.loadNextPage()

        #expect(await source.requestedPages == [1])
        #expect(paginator.phase == .loaded(hasMore: false))
    }

    @Test func skipsPhotosAlreadyLoaded() async {
        // "b" moved from page 1 to page 2 because a new photo was published meanwhile.
        let source = ScriptedPages([
            .success(page(["a", "b"], hasMore: true)),
            .success(page(["b", "c"], hasMore: true)),
        ])
        let paginator = Paginator(loadPage: source.load)

        await paginator.loadNextPage()
        await paginator.loadNextPage()

        #expect(paginator.items.map(\.id) == ["a", "b", "c"])
    }

    // MARK: No duplicated requests

    @Test func ignoresCallsWhileALoadIsInFlight() async {
        let gate = Gate()
        let source = ScriptedPages([.success(page(["a"], hasMore: true))], gate: gate)
        let paginator = Paginator(loadPage: source.load)

        let firstLoad = Task { await paginator.loadNextPage() }
        while paginator.phase != .loadingFirstPage { await Task.yield() }

        // Several cells reaching the end at once.
        await paginator.loadNextPage()
        await paginator.loadNextPage()

        await gate.open()
        await firstLoad.value

        #expect(await source.requestedPages == [1])
        #expect(paginator.items.map(\.id) == ["a"])
    }

    // MARK: Failures

    @Test func firstPageFailureThenRetry() async {
        let source = ScriptedPages([
            .failure(DomainError.offline),
            .success(page(["a"], hasMore: true)),
        ])
        let paginator = Paginator(loadPage: source.load)

        await paginator.loadNextPage()
        #expect(paginator.phase == .failed(.offline, isFirstPage: true))
        #expect(paginator.items.isEmpty)

        await paginator.loadNextPage()
        #expect(await source.requestedPages == [1, 1])
        #expect(paginator.items.map(\.id) == ["a"])
    }

    @Test func nextPageFailureKeepsLoadedPhotosAndRetriesSamePage() async {
        let source = ScriptedPages([
            .success(page(["a"], hasMore: true)),
            .failure(DomainError.rateLimited),
            .success(page(["b"], hasMore: true)),
        ])
        let paginator = Paginator(loadPage: source.load)

        await paginator.loadNextPage()
        await paginator.loadNextPage()
        #expect(paginator.phase == .failed(.rateLimited, isFirstPage: false))
        #expect(paginator.items.map(\.id) == ["a"])

        await paginator.loadNextPage()
        #expect(await source.requestedPages == [1, 2, 2])
        #expect(paginator.items.map(\.id) == ["a", "b"])
    }

    @Test func unknownErrorsBecomeInvalidResponse() async {
        let source = ScriptedPages([.failure(URLError(.badURL))])
        let paginator = Paginator(loadPage: source.load)

        await paginator.loadNextPage()

        #expect(paginator.phase == .failed(.invalidResponse, isFirstPage: true))
    }

    @Test func cancellationIsNotAFailure() async {
        let source = ScriptedPages([.failure(CancellationError())])
        let paginator = Paginator(loadPage: source.load)

        await paginator.loadNextPage()

        #expect(paginator.phase == .idle)
    }
}

// MARK: - Helpers

private func page(_ ids: [PhotoID], hasMore: Bool) -> Page<Photo> {
    Page(items: ids.map { Photo(id: $0, caption: nil, width: 1, height: 1, variants: []) }, hasMore: hasMore)
}

/// Returns scripted results in order and records which pages were requested.
private actor ScriptedPages {
    private var responses: [Result<Page<Photo>, any Error>]
    private let gate: Gate?
    private(set) var requestedPages: [Int] = []

    init(_ responses: [Result<Page<Photo>, any Error>], gate: Gate? = nil) {
        self.responses = responses
        self.gate = gate
    }

    func load(_ page: Int) async throws -> Page<Photo> {
        requestedPages.append(page)
        await gate?.wait()
        return try responses.removeFirst().get()
    }
}

/// Suspends callers of `wait()` until `open()` is called.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
