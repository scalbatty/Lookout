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
}
