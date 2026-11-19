import Foundation
import ImageIO
import UIKit

/// Decodes encoded image data straight to the size it will be displayed at.
enum ImageDecoder {
    /// Decodes `data` so its longest edge is at most `maxPixelSize`.
    ///
    /// ImageIO reads the file at the reduced size instead of decoding the
    /// full original and scaling it down, and decodes it right away
    /// (`ShouldCacheImmediately`), so the main thread never has to decode
    /// lazily on first draw.
    static func downsample(_ data: Data, maxPixelSize: Int) throws -> UIImage {
        // Don't decode or cache anything when merely opening the source.
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw URLError(.cannotDecodeContentData)
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1),
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw URLError(.cannotDecodeContentData)
        }
        return UIImage(cgImage: image)
    }
}
