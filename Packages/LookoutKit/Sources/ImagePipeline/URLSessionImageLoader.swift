import Foundation
import ImageLoading
import UIKit

/// `ImageLoading` over `URLSession`: downloads, decodes off the main thread
/// at the size it will be displayed at, and keeps decoded images in memory
/// so they can be shown again without waiting. Downloaded files are also
/// kept on disk, so an image evicted from memory comes back without the
/// network.
public struct URLSessionImageLoader: ImageLoading {
    private let session: URLSession
    private let cache: MemoryImageCache

    /// A session whose `URLCache` keeps downloaded images on disk.
    ///
    /// Unsplash image URLs never change content (each identifies one photo
    /// at one size), so cached files are used without revalidating them.
    /// - Parameter diskCapacity: About 3,000 grid-sized JPEGs with the default.
    public static func makeDiskCachedSession(diskCapacity: Int = 300 * 1024 * 1024) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            // Decoded images already live in MemoryImageCache.
            memoryCapacity: 0,
            diskCapacity: diskCapacity,
            directory: URL.cachesDirectory.appending(path: "Images", directoryHint: .isDirectory)
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }

    public init(
        session: URLSession = makeDiskCachedSession(),
        cache: MemoryImageCache = MemoryImageCache()
    ) {
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
