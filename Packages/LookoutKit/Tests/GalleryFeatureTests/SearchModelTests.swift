import Domain
import Foundation
import Testing
@testable import GalleryFeature

@MainActor
struct SearchModelTests {
    private func model() -> SearchModel {
        SearchModel(repository: EmptyRepository(), typingPause: .milliseconds(20))
    }

    @Test func searchesOnceTypingPauses() async {
        let search = model()
        let typing = Task { await search.update(for: "tiger") }
        #expect(search.query == nil) // still waiting

        await typing.value
        #expect(search.query == SearchQuery("tiger"))
        #expect(search.results != nil)
    }

    @Test func cancelledTypingNeverBecomesAQuery() async {
        let search = model()
        let typing = Task { await search.update(for: "ti") }
        typing.cancel() // the user typed again
        await typing.value

        #expect(search.query == nil)
        #expect(search.results == nil)
    }

    @Test func sameQueryKeepsTheSameResults() async {
        let search = model()
        await search.update(for: "tiger")
        let results = search.results

        await search.update(for: "tiger ")

        #expect(search.results === results)
    }

    @Test func newQueryGetsNewResults() async {
        let search = model()
        await search.update(for: "tiger")
        let tigers = search.results

        await search.update(for: "lion")

        #expect(search.query == SearchQuery("lion"))
        #expect(search.results !== tigers)
    }

    @Test func clearingTheFieldReturnsToTheFeedImmediately() async {
        let search = model()
        await search.update(for: "tiger")

        // Even cancelled at once, clearing doesn't wait.
        let clearing = Task { await search.update(for: "  ") }
        clearing.cancel()
        await clearing.value

        #expect(search.query == nil)
        #expect(search.results == nil)
    }
}

private struct EmptyRepository: PhotoRepository {
    func editorialPhotos(page: Int) async throws -> Page<Photo> { Page(items: [], hasMore: false) }
    func searchPhotos(matching query: SearchQuery, page: Int) async throws -> Page<Photo> { Page(items: [], hasMore: false) }
}
