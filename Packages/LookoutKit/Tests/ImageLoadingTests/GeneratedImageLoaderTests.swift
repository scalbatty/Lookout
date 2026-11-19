import Foundation
import Testing
@testable import ImageLoading

struct GeneratedImageLoaderTests {
    private let request = ImageRequest(url: URL(string: "https://example.com/a.jpg")!, maxPixelSize: 300)

    @Test func drawsAtRequestedPixelSize() async throws {
        let image = try await GeneratedImageLoader().image(for: request)
        #expect(image.size.width * image.scale == 300)
        #expect(image.size.height * image.scale == 300)
    }

    @Test func sameURLGetsSameColor() {
        let url = URL(string: "https://example.com/a.jpg")!
        #expect(GeneratedImageLoader.hue(for: url) == GeneratedImageLoader.hue(for: url))
        #expect(GeneratedImageLoader.hue(for: url) != GeneratedImageLoader.hue(for: URL(string: "https://example.com/b.jpg")!))
    }

    @Test func throwsConfiguredFailure() async {
        struct Boom: Error {}
        await #expect(throws: Boom.self) {
            try await GeneratedImageLoader(failing: Boom()).image(for: request)
        }
    }

    @Test func cancellationStopsTheLoad() async {
        let task = Task { try await GeneratedImageLoader(latency: .seconds(10)).image(for: request) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
