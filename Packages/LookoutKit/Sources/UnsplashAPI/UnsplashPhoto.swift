import Foundation

/// A photo as returned by the Unsplash API. Only the fields Lookout uses are decoded.
struct UnsplashPhoto: Decodable, Sendable {
    let id: String
    let width: Int
    let height: Int
    let description: String?
    let altDescription: String?
    let urls: URLs
    /// Present (non-null) only for paid placements in the editorial feed.
    let sponsorship: Sponsorship?

    struct URLs: Decodable, Sendable {
        let full: URL?
        let regular: URL?
        let small: URL?
        let thumb: URL?
    }

    /// Its content isn't used yet; only its presence matters.
    struct Sponsorship: Decodable, Sendable {}
}

/// The body of `GET /search/photos`. `GET /photos` returns a bare array instead.
struct UnsplashSearchResponse: Decodable, Sendable {
    let total: Int
    let totalPages: Int
    let results: [UnsplashPhoto]
}

extension JSONDecoder {
    /// Decoder configured for Unsplash's snake_case keys.
    static func unsplash() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
