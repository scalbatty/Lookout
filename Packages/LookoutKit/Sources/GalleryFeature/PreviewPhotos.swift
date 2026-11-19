#if DEBUG
import Domain
import Foundation

/// Sample photos for previews. Their URLs are never downloaded: previews
/// use `GeneratedImageLoader`.
enum PreviewPhotos {
    static let landscape = make("landscape", caption: "Aerial view of a beach with turquoise water", width: 4000, height: 3000)
    static let portrait = make("portrait", caption: "A long narrow corridor with recessed lighting", width: 3000, height: 4500)
    static let noCaption = make("no-caption", caption: nil, width: 3000, height: 3000)
    static let sponsored = make("sponsored", caption: "The Real Aussie Feeling", width: 2912, height: 3640, isSponsored: true)
    static let longCaption = make(
        "long-caption",
        caption: "Tigers walk through a grassy forest clearing at dawn, with mist rising between the trees behind them",
        width: 6660,
        height: 4440
    )

    static let all = [landscape, portrait, noCaption, sponsored, longCaption]

    /// A page of 10 photos with IDs unique to that page, for endless previews.
    static func page(_ number: Int) -> [Photo] {
        (0..<10).map { index in
            let base = all[index % all.count]
            return Photo(
                id: PhotoID(rawValue: "\(base.id.rawValue)-\(number)-\(index)"),
                caption: base.caption,
                width: base.width,
                height: base.height,
                variants: base.variants.map {
                    ImageVariant(url: $0.url.appending(queryItems: [URLQueryItem(name: "p", value: "\(number)-\(index)")]), pixelWidth: $0.pixelWidth)
                },
                isSponsored: base.isSponsored
            )
        }
    }

    private static func make(_ id: PhotoID, caption: String?, width: Int, height: Int, isSponsored: Bool = false) -> Photo {
        let variants = [200, 400, 1080, width].map {
            ImageVariant(url: URL(string: "https://example.com/\(id.rawValue)/\($0).jpg")!, pixelWidth: $0)
        }
        return Photo(id: id, caption: caption, width: width, height: height, variants: variants, isSponsored: isSponsored)
    }
}
#endif
