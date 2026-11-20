import Foundation

/// Serves recorded `GET /photos` responses instead of calling the API, for
/// reproducible profiling and long scrolls without spending request quota.
///
/// Pages cycle through the recordings; from the second cycle on, photo IDs
/// get a suffix so the feed stays endless instead of being deduplicated.
/// Search isn't recorded and returns no results.
struct ReplayHTTPClient: HTTPClient {
    /// Recorded editorial pages, in page order.
    let pages: [Data]
    /// Wait before each response, to see loading states.
    var latency: Duration = .zero

    func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: latency)
        guard let url = request.url else { throw URLError(.badURL) }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let page = components?.queryItems?.first { $0.name == "page" }?.value.flatMap(Int.init) ?? 1

        let body: Data
        if components?.path == "/photos", !pages.isEmpty {
            let cycle = (page - 1) / pages.count
            body = try Self.renamingIDs(in: pages[(page - 1) % pages.count], cycle: cycle)
        } else {
            body = Data(#"{"total":0,"total_pages":0,"results":[]}"#.utf8)
        }
        return (body, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    private static func renamingIDs(in page: Data, cycle: Int) throws -> Data {
        guard cycle > 0, var photos = try JSONSerialization.jsonObject(with: page) as? [[String: Any]] else {
            return page
        }
        for index in photos.indices {
            photos[index]["id"] = "\(photos[index]["id"] ?? "")-\(cycle)"
        }
        return try JSONSerialization.data(withJSONObject: photos)
    }
}

extension UnsplashPhotoRepository {
    /// A repository replaying recorded editorial pages (files containing a
    /// `GET /photos` response body), in page order. No network, no key.
    /// `latency` delays each response, to see loading states.
    public static func replaying(recordedPages: [URL], latency: Duration = .zero) throws -> UnsplashPhotoRepository {
        let pages = try recordedPages.map { try Data(contentsOf: $0) }
        return UnsplashPhotoRepository(accessKey: "replay", http: ReplayHTTPClient(pages: pages, latency: latency))
    }
}
