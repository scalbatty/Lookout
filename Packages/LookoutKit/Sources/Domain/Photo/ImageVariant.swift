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
    ///
    /// A single pass without allocating: views call this while rendering.
    /// Among equal widths, the first variant wins for "smallest sufficient"
    /// and the last for "largest", as a stable sort would pick them.
    public func bestVariant(forPixelWidth pixelWidth: Int) -> ImageVariant? {
        var smallestSufficient: ImageVariant?
        var largest: ImageVariant?
        for variant in variants {
            if variant.pixelWidth >= pixelWidth,
               variant.pixelWidth < (smallestSufficient?.pixelWidth ?? .max) {
                smallestSufficient = variant
            }
            if variant.pixelWidth >= (largest?.pixelWidth ?? .min) {
                largest = variant
            }
        }
        return smallestSufficient ?? largest
    }
}
