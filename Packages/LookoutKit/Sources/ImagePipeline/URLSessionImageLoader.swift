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
    /// One download and decode per image, shared by everyone asking for it.
    private let inFlight: InFlightLoads

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
        self.inFlight = InFlightLoads { [session, cache] request in
            try await Self.download(request, session: session, cache: cache)
        }
    }

    /// `@concurrent`: downloading and decoding never run on the caller's
    /// actor (the main actor, from views).
    @concurrent
    public func image(for request: ImageRequest) async throws -> UIImage {
        if let cached = cachedImage(for: request) {
            return cached
        }
        return try await inFlight.image(for: request)
    }

    public func prefetch(_ requests: [ImageRequest]) {
        inFlight.prefetch(requests.filter { cachedImage(for: $0) == nil })
    }

    @concurrent
    private static func download(
        _ request: ImageRequest,
        session: URLSession,
        cache: MemoryImageCache
    ) async throws -> UIImage {
        let urlRequest = URLRequest(url: request.url)
        let (data, response) = try await session.data(for: urlRequest)
        try Task.checkCancellation()
        // An error page isn't an image. Drop it from the disk cache too,
        // which would otherwise return it again without asking the server.
        if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
            session.configuration.urlCache?.removeCachedResponse(for: urlRequest)
            throw URLError(.badServerResponse)
        }
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
