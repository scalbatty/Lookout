import Domain
import Foundation
import Testing
@testable import UnsplashAPI

struct ReplayHTTPClientTests {
    private func repository() throws -> UnsplashPhotoRepository {
        // The recorded 3-photo fixture, used as a feed of two identical pages.
        let page = try Fixture.data("photos-page")
        return UnsplashPhotoRepository(accessKey: "replay", http: ReplayHTTPClient(pages: [page, page]))
    }

    @Test func servesRecordedPagesInOrder() async throws {
        let page = try await repository().editorialPhotos(page: 1)
        #expect(page.items.map(\.id) == ["WWyBQvJqvW8", "IIdlT7JMk9w", "B5RL__RyWio"])
        #expect(page.hasMore)
    }

    @Test func cyclesWithUniqueIDsAfterTheLastRecording() async throws {
        let repository = try repository()
        let firstCycle = try await repository.editorialPhotos(page: 2)
        let secondCycle = try await repository.editorialPhotos(page: 3)

        #expect(firstCycle.items.first?.id == "WWyBQvJqvW8")
        #expect(secondCycle.items.first?.id == "WWyBQvJqvW8-1")
        // Everything but the ID is the recorded photo.
        #expect(secondCycle.items.first?.variants == firstCycle.items.first?.variants)
    }

    @Test func searchReturnsNothing() async throws {
        let page = try await repository().searchPhotos(matching: SearchQuery("tigers")!, page: 1)
        #expect(page.items.isEmpty)
        #expect(!page.hasMore)
    }
}
