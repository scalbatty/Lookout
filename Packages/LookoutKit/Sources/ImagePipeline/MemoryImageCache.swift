import Foundation
import os
import UIKit

/// Decoded images kept in memory, bounded by their size in bytes.
///
/// Images are grouped by URL, each URL holding the pixel sizes it was loaded
/// at, so a view can ask both for an exact size and for "anything loaded for
/// this photo". `NSCache` evicts least recently used entries past the limit
/// and empties itself under memory pressure.
public final class MemoryImageCache: @unchecked Sendable {
    // @unchecked: NSCache is thread-safe, entries are immutable, and
    // inserts are serialised by `insertLock`.

    /// The length of an image's longest edge, in pixels: the
    /// `ImageRequest.maxPixelSize` it was decoded at.
    private typealias PixelSize = Int

    /// The sizes loaded for one URL. Replaced, never mutated, on insert.
    private final class Entry {
        let images: [PixelSize: UIImage]
        init(images: [PixelSize: UIImage]) { self.images = images }
    }

    private let storage = NSCache<NSURL, Entry>()
    /// Two sizes of one URL can finish loading at once (grid and full
    /// screen); without this, one insert could overwrite the other's entry.
    private let insertLock = OSAllocatedUnfairLock()

    /// - Parameter costLimit: Total decoded bytes to keep, about 70 grid
    ///   cells on a 3× iPhone with the default.
    public init(costLimit: Int = 100 * 1024 * 1024) {
        storage.totalCostLimit = costLimit
    }

    func image(for url: URL, maxPixelSize: Int) -> UIImage? {
        storage.object(forKey: url as NSURL)?.images[maxPixelSize]
    }

    func largestImage(forAnyOf urls: [URL]) -> UIImage? {
        var best: (size: PixelSize, image: UIImage)?
        for url in urls {
            guard let entry = storage.object(forKey: url as NSURL) else { continue }
            for (size, image) in entry.images where size > (best?.size ?? 0) {
                best = (size, image)
            }
        }
        return best?.image
    }

    func insert(_ image: UIImage, for url: URL, maxPixelSize: Int) {
        insertLock.withLock {
            var images = storage.object(forKey: url as NSURL)?.images ?? [:]
            images[maxPixelSize] = image
            let cost = images.values.reduce(0) { $0 + Self.cost(of: $1) }
            storage.setObject(Entry(images: images), forKey: url as NSURL, cost: cost)
        }
    }

    /// Decoded bytes held by the image.
    static func cost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
