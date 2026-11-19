import Foundation
import ImageLoading
import Testing
import UIKit
@testable import ImagePipeline

/// Serves a small JPEG for every request and counts them.
final class StubImageProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestCount = 0
    static let jpeg: Data = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300), format: format)
            .jpegData(withCompressionQuality: 0.8) { context in
                UIColor.blue.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            }
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.jpeg)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct URLSessionImageLoaderTests {
    private func loader() -> URLSessionImageLoader {
        StubImageProtocol.requestCount = 0
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubImageProtocol.self]
        return URLSessionImageLoader(session: URLSession(configuration: configuration))
    }

    private let request = ImageRequest(url: URL(string: "https://example.com/a.jpg")!, maxPixelSize: 200)

    @Test func secondLoadComesFromMemory() async throws {
        let loader = loader()
        let first = try await loader.image(for: request)
        let second = try await loader.image(for: request)

        #expect(StubImageProtocol.requestCount == 1)
        #expect(first === second)
    }

    @Test func cachedImageIsAvailableSynchronouslyAfterALoad() async throws {
        let loader = loader()
        #expect(loader.cachedImage(for: request) == nil)

        let loaded = try await loader.image(for: request)

        #expect(loader.cachedImage(for: request) === loaded)
        #expect(loader.largestCachedImage(forAnyOf: [request.url]) === loaded)
    }

    @Test func imagesAreDownsampledToTheRequest() async throws {
        let image = try await loader().image(for: request)
        #expect(image.cgImage?.width == 200)
        #expect(image.cgImage?.height == 150)
    }
}
