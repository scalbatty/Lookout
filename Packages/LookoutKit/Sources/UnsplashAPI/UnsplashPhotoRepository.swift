import Domain
import Foundation
import os

/// `PhotoRepository` backed by the Unsplash API.
///
/// Stateless: each call performs exactly one request. Callers (the paginator)
/// are responsible for not requesting the same page twice.
public struct UnsplashPhotoRepository: PhotoRepository {
    private static let baseURL = URL(string: "https://api.unsplash.com")!
    /// The API's maximum page size.
    public static let maxPerPage = 30

    private struct Endpoint: RawRepresentable {
        let rawValue: String

        static let photos = Endpoint(rawValue: "/photos")
        static let searchPhotos = Endpoint(rawValue: "/search/photos")
    }

    private struct QueryParameter: RawRepresentable {
        let rawValue: String

        static let page = QueryParameter(rawValue: "page")
        static let perPage = QueryParameter(rawValue: "per_page")
        static let query = QueryParameter(rawValue: "query")

        func item(_ value: String) -> URLQueryItem {
            URLQueryItem(name: rawValue, value: value)
        }
    }

    private let accessKey: String
    private let perPage: Int
    private let http: any HTTPClient
    private let logger = Logger(subsystem: "app.lookout", category: "UnsplashAPI")

    /// - Parameter perPage: Photos per request, up to `maxPerPage`. Defaults to
    ///   the maximum, to make the most of the hourly request quota.
    public init(accessKey: String, perPage: Int = maxPerPage, session: URLSession = .shared) {
        self.init(accessKey: accessKey, perPage: perPage, http: session)
    }

    init(accessKey: String, perPage: Int = maxPerPage, http: any HTTPClient) {
        assert((1...Self.maxPerPage).contains(perPage), "Unsplash accepts 1...\(Self.maxPerPage) photos per page")
        self.accessKey = accessKey
        self.perPage = perPage
        self.http = http
    }

    // `@concurrent`: requests and JSON decoding always run off the caller's
    // actor (typically the main actor), whatever the module's default
    // isolation settings are.

    @concurrent
    public func editorialPhotos(page: Int) async throws -> Page<Photo> {
        let data = try await get(.photos, page: page)
        let photos = try decode([UnsplashPhoto].self, from: data)
        // The editorial feed has no total; it ends when a page comes back empty.
        return Page(items: photos.map(\.domainPhoto), hasMore: !photos.isEmpty)
    }

    @concurrent
    public func searchPhotos(matching query: SearchQuery, page: Int) async throws -> Page<Photo> {
        let data = try await get(.searchPhotos, page: page, extraQuery: [QueryParameter.query.item(query.text)])
        let response = try decode(UnsplashSearchResponse.self, from: data)
        return Page(items: response.results.map(\.domainPhoto), hasMore: page < response.totalPages)
    }

    // MARK: - Request

    private func get(_ endpoint: Endpoint, page: Int, extraQuery: [URLQueryItem] = []) async throws -> Data {
        assert(page >= 1, "Unsplash pages are 1-based")
        let path = endpoint.rawValue

        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = extraQuery + [
            QueryParameter.page.item(String(page)),
            QueryParameter.perPage.item(String(perPage)),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (data, response): (Data, HTTPURLResponse)
        do {
            (data, response) = try await http.response(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            logger.error("GET \(path, privacy: .public) page \(page) failed: network unreachable")
            // Any transport failure is presented as "can't reach the network".
            throw DomainError.offline
        }

        let remaining = response.value(forHTTPHeaderField: "X-Ratelimit-Remaining")
        logger.debug("GET \(path, privacy: .public) page \(page) → \(response.statusCode), quota left: \(remaining ?? "?", privacy: .public)")

        switch response.statusCode {
        case 200..<300:
            return data
        case 401:
            throw DomainError.unauthorized
        case 403 where remaining == "0":
            throw DomainError.rateLimited
        default:
            throw DomainError.unexpectedStatus(response.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.unsplash().decode(type, from: data)
        } catch {
            logger.error("Decoding \(String(describing: type), privacy: .public) failed: \(error, privacy: .public)")
            throw DomainError.invalidResponse
        }
    }
}
