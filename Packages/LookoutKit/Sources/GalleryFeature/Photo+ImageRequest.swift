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

    /// The request for this photo in a grid cell of `size` points. The one
    /// place this is computed, so prefetched images are exactly the ones
    /// cells then look up.
    func gridImageRequest(size: CGSize, displayScale: CGFloat) -> ImageRequest? {
        let scale = min(displayScale, Self.maxGridImageScale)
        return imageRequest(filling: CGSize(width: size.width * scale, height: size.height * scale))
    }

    /// The request for showing this photo cropped to fill a box of `size`
    /// pixels: scaled until it covers the box, then capped so neither edge
    /// exceeds `maxLongEdgeFactor` times the box's. Beyond the cap, very
    /// elongated photos are slightly upscaled in their cell.
    func imageRequest(filling size: CGSize) -> ImageRequest? {
        guard size.width > 0, size.height > 0 else { return nil }
        let width = Double(size.width), height = Double(size.height)
        let photoWidth = Double(max(self.width, 1)), photoHeight = photoWidth / aspectRatio
        let cover = max(width / photoWidth, height / photoHeight)
        let (coverWidth, coverHeight) = (photoWidth * cover, photoHeight * cover)
        let cap = min(1, Self.maxLongEdgeFactor * width / coverWidth, Self.maxLongEdgeFactor * height / coverHeight)
        let neededWidth = (coverWidth * cap).rounded(.up)
        let longEdge = (max(coverWidth, coverHeight) * cap).rounded(.up)
        guard let variant = bestVariant(forPixelWidth: Int(neededWidth)) else { return nil }
        return ImageRequest(url: variant.url, maxPixelSize: Int(longEdge))
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
