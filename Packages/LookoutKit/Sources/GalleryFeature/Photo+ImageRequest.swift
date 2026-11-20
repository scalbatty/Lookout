import CoreGraphics
import Domain
import ImageLoading

extension Photo {
    /// The longest edge requested, relative to the square's side. Extreme
    /// panoramas would otherwise need huge downloads and decodes for a crop.
    static let maxLongEdgeFactor = 2.0

    /// Grid images are loaded at most at 2× even on 3× screens: at cell size
    /// the difference is hard to see, while each image takes ~2.25× less
    /// memory and uses a smaller download (`small` instead of `regular`).
    /// The full-screen view keeps the screen's real scale.
    static let maxGridImageScale: CGFloat = 2

    /// The request for this photo in a grid cell of `side` points. The one
    /// place this is computed, so prefetched images are exactly the ones
    /// cells then look up.
    func gridImageRequest(side: CGFloat, displayScale: CGFloat) -> ImageRequest? {
        let scale = min(displayScale, Self.maxGridImageScale)
        return imageRequest(fillingSquareOf: Int((side * scale).rounded(.up)))
    }

    /// The request for showing this photo cropped to fill a square of
    /// `side` pixels: the shorter edge must cover the square, so the longer
    /// edge is `side × (long / short)`, capped at `maxLongEdgeFactor × side`.
    /// Beyond the cap, very elongated photos are slightly upscaled in their cell.
    func imageRequest(fillingSquareOf side: Int) -> ImageRequest? {
        let longOverShort = min(max(aspectRatio, 1 / aspectRatio), Self.maxLongEdgeFactor)
        let longEdge = Int((Double(side) * longOverShort).rounded(.up))
        // Landscape: the width is the long edge. Portrait: the width covers the square.
        let neededWidth = aspectRatio >= 1 ? longEdge : side
        guard let variant = bestVariant(forPixelWidth: neededWidth) else { return nil }
        return ImageRequest(url: variant.url, maxPixelSize: longEdge)
    }

    /// The request for showing this photo whole, fitted inside a box of
    /// `size` pixels.
    func imageRequest(fitting size: CGSize) -> ImageRequest? {
        guard size.width > 0, size.height > 0 else { return nil }
        let fitsWidth = aspectRatio >= Double(size.width / size.height)
        let width = fitsWidth ? Double(size.width) : Double(size.height) * aspectRatio
        let height = fitsWidth ? Double(size.width) / aspectRatio : Double(size.height)
        guard let variant = bestVariant(forPixelWidth: Int(width.rounded(.up))) else { return nil }
        return ImageRequest(url: variant.url, maxPixelSize: Int(max(width, height).rounded(.up)))
    }
}
