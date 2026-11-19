import Domain
import Foundation

extension UnsplashPhoto {
    /// Widths of Unsplash's named renditions. Unsplash documents these as fixed
    /// sizes; a test checks them against the `w=` parameter of recorded URLs.
    /// `full` is the original, so its width is the photo's own width.
    enum RenditionWidth {
        static let thumb = 200
        static let small = 400
        static let regular = 1080
    }

    /// Converts to Lookout's source-agnostic model.
    var domainPhoto: Photo {
        Photo(
            id: PhotoID(rawValue: id),
            caption: caption,
            width: width,
            height: height,
            variants: variants,
            isSponsored: sponsorship != nil
        )
    }

    /// `alt_description` first, then `description`. Blank values count as missing.
    var caption: String? {
        [altDescription, description]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    /// Renditions with a usable URL. `raw` is skipped: it has no size applied.
    var variants: [ImageVariant] {
        let candidates: [(URL?, Int)] = [
            (urls.thumb, RenditionWidth.thumb),
            (urls.small, RenditionWidth.small),
            (urls.regular, RenditionWidth.regular),
            (urls.full, width),
        ]
        return candidates.compactMap { url, width in
            url.map { ImageVariant(url: $0, pixelWidth: width) }
        }
    }
}
