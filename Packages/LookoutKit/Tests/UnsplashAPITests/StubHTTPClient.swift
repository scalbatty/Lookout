import Foundation
@testable import UnsplashAPI

/// Answers requests with a canned response, or a thrown error.
struct StubHTTPClient: HTTPClient {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }

    /// Always responds with `body` and the given status and headers.
    static func responding(
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data("[]".utf8),
        inspect: @escaping @Sendable (URLRequest) -> Void = { _ in }
    ) -> StubHTTPClient {
        StubHTTPClient { request in
            inspect(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            return (body, response)
        }
    }

    static func failing(with error: any Error) -> StubHTTPClient {
        StubHTTPClient { _ in throw error }
    }
}
