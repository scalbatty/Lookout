import Domain
import Foundation
import Testing
@testable import UnsplashAPI

struct UnsplashPhotoRepositoryTests {
    private func repository(_ http: StubHTTPClient) -> UnsplashPhotoRepository {
        UnsplashPhotoRepository(accessKey: "test-key", http: http)
    }

    private let tigers = SearchQuery("tigers")!

    // MARK: Requests

    @Test func feedRequest() async throws {
        let http = StubHTTPClient.responding { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            #expect(components.host == "api.unsplash.com")
            #expect(components.path == "/photos")
            #expect(components.queryItems?.contains(URLQueryItem(name: "page", value: "2")) == true)
            #expect(components.queryItems?.contains(URLQueryItem(name: "per_page", value: "30")) == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Client-ID test-key")
            #expect(request.value(forHTTPHeaderField: "Accept-Version") == "v1")
        }
        _ = try await repository(http).editorialPhotos(page: 2)
    }

    @Test func customPageSize() async throws {
        let http = StubHTTPClient.responding { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            #expect(components.queryItems?.contains(URLQueryItem(name: "per_page", value: "12")) == true)
        }
        _ = try await UnsplashPhotoRepository(accessKey: "test-key", perPage: 12, http: http).editorialPhotos(page: 1)
    }

    @Test func searchRequest() async throws {
        let body = Data(#"{"total":0,"total_pages":0,"results":[]}"#.utf8)
        let http = StubHTTPClient.responding(body: body) { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            #expect(components.path == "/search/photos")
            #expect(components.queryItems?.contains(URLQueryItem(name: "query", value: "tigers")) == true)
            #expect(components.queryItems?.contains(URLQueryItem(name: "page", value: "1")) == true)
        }
        _ = try await repository(http).searchPhotos(matching: tigers, page: 1)
    }

    @Test func searchQueryEncodesPlusSigns() async throws {
        let body = Data(#"{"total":0,"total_pages":0,"results":[]}"#.utf8)
        let http = StubHTTPClient.responding(body: body) { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.percentEncodedQuery ?? ""
            #expect(query.contains("query=c%2B%2B%20%26%20a%3Db"))
        }
        _ = try await repository(http).searchPhotos(matching: SearchQuery("c++ & a=b")!, page: 1)
    }

    // MARK: Pages

    @Test func feedPageFromRecordedResponse() async throws {
        let page = try await repository(.responding(body: Fixture.data("photos-page"))).editorialPhotos(page: 1)
        #expect(page.items.count == 3)
        #expect(page.hasMore)
    }

    @Test func emptyFeedPageHasNoMore() async throws {
        let page = try await repository(.responding(body: Data("[]".utf8))).editorialPhotos(page: 99)
        #expect(page.items.isEmpty)
        #expect(!page.hasMore)
    }

    @Test(arguments: [(page: 1, hasMore: true), (page: 1059, hasMore: true), (page: 1060, hasMore: false)])
    func searchHasMoreUntilLastPage(page: Int, hasMore: Bool) async throws {
        // Recorded response reports total_pages = 1060.
        let result = try await repository(.responding(body: Fixture.data("search-photos-page")))
            .searchPhotos(matching: tigers, page: page)
        #expect(result.items.count == 3)
        #expect(result.hasMore == hasMore)
    }

    // MARK: Errors

    @Test func unauthorized() async {
        await #expect(throws: DomainError.unauthorized) {
            try await repository(.responding(status: 401)).editorialPhotos(page: 1)
        }
    }

    @Test func rateLimitedWhenQuotaIsExhausted() async {
        let http = StubHTTPClient.responding(status: 403, headers: ["X-Ratelimit-Remaining": "0"])
        await #expect(throws: DomainError.rateLimited) {
            try await repository(http).editorialPhotos(page: 1)
        }
    }

    @Test func forbiddenWithQuotaLeftIsUnexpected() async {
        let http = StubHTTPClient.responding(status: 403, headers: ["X-Ratelimit-Remaining": "12"])
        await #expect(throws: DomainError.unexpectedStatus(403)) {
            try await repository(http).editorialPhotos(page: 1)
        }
    }

    @Test func serverError() async {
        await #expect(throws: DomainError.unexpectedStatus(500)) {
            try await repository(.responding(status: 500)).editorialPhotos(page: 1)
        }
    }

    @Test func undecodableBody() async {
        await #expect(throws: DomainError.invalidResponse) {
            try await repository(.responding(body: Data("not json".utf8))).editorialPhotos(page: 1)
        }
    }

    @Test func noConnection() async {
        await #expect(throws: DomainError.offline) {
            try await repository(.failing(with: URLError(.notConnectedToInternet))).editorialPhotos(page: 1)
        }
    }

    @Test func cancelledRequestThrowsCancellation() async {
        await #expect(throws: CancellationError.self) {
            try await repository(.failing(with: URLError(.cancelled))).editorialPhotos(page: 1)
        }
    }
}
