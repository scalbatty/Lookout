import Foundation
import ImageLoading
import UIKit

/// `ImageLoading` over `URLSession`: downloads, decodes off the main thread
/// at the size it will be displayed at, and keeps decoded images in memory
/// so they can be shown again without waiting.
public struct URLSessionImageLoader: ImageLoading {
    private let session: URLSession
    private let cache: MemoryImageCache

    public init(session: URLSession = .shared, cache: MemoryImageCache = MemoryImageCache()) {
        self.session = session
        self.cache = cache
    }

    /// `@concurrent`: downloading and decoding never run on the caller's
    /// actor (the main actor, from views).
    @concurrent
    public func image(for request: ImageRequest) async throws -> UIImage {
        if let cached = cachedImage(for: request) {
            return cached
        }
        let (data, _) = try await session.data(from: request.url)
        try Task.checkCancellation()
        let image = try ImageDecoder.downsample(data, maxPixelSize: request.maxPixelSize)
        cache.insert(image, for: request.url, maxPixelSize: request.maxPixelSize)
        return image
    }

    public func cachedImage(for request: ImageRequest) -> UIImage? {
        cache.image(for: request.url, maxPixelSize: request.maxPixelSize)
    }

    public func largestCachedImage(forAnyOf urls: [URL]) -> UIImage? {
        cache.largestImage(forAnyOf: urls)
    }
}
