import Foundation
import UIKit

/// What to load, and how big it will be displayed.
public struct ImageRequest: Hashable, Sendable {
    public let url: URL
    /// The longest edge the image will occupy on screen, in pixels.
    /// Loaders decode to this size instead of the full original.
    public let maxPixelSize: Int

    public init(url: URL, maxPixelSize: Int) {
        self.url = url
        self.maxPixelSize = maxPixelSize
    }
}

/// Loads images for display. Features depend on this interface only.
///
/// Cancelling the calling task should stop any work no other caller needs,
/// and throw `CancellationError`.
public protocol ImageLoading: Sendable {
    func image(for request: ImageRequest) async throws -> UIImage

    /// The image for `request` if it's already in memory, without waiting.
    /// Views call it while rendering, so it must be cheap.
    func cachedImage(for request: ImageRequest) -> UIImage?

    /// The largest image already in memory for any of `urls`, at whatever
    /// size it was loaded. Lets a view show what's available (e.g. the grid
    /// thumbnail) while a larger size loads.
    func largestCachedImage(forAnyOf urls: [URL]) -> UIImage?
}

extension ImageLoading {
    /// Loaders without a cache never have anything in memory.
    public func cachedImage(for request: ImageRequest) -> UIImage? { nil }
    public func largestCachedImage(forAnyOf urls: [URL]) -> UIImage? { nil }
}
