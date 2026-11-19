import Foundation

/// One downloadable rendition of a photo at a known width.
public struct ImageVariant: Hashable, Sendable {
    public let url: URL
    public let pixelWidth: Int

    public init(url: URL, pixelWidth: Int) {
        self.url = url
        self.pixelWidth = pixelWidth
    }
}

extension Photo {
    /// The smallest variant at least `pixelWidth` wide, or the largest one
    /// if none is wide enough. `nil` only when the photo has no variants.
    public func bestVariant(forPixelWidth pixelWidth: Int) -> ImageVariant? {
        let byWidth = variants.sorted { $0.pixelWidth < $1.pixelWidth }
        return byWidth.first { $0.pixelWidth >= pixelWidth } ?? byWidth.last
    }
}
