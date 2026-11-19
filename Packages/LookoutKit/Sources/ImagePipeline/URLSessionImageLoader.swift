import Foundation
import ImageLoading
import UIKit

/// Deliberately naive `ImageLoading`: one download per request, decoded at
/// full size, nothing cached beyond `URLSession`'s default behaviour.
///
/// It's the measured "before" for the image pipeline: each improvement
/// (downsampling, memory cache, request deduplication, prefetching) will
/// replace a piece of it, with Instruments numbers in the commit.
public struct URLSessionImageLoader: ImageLoading {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func image(for request: ImageRequest) async throws -> UIImage {
        // `request.maxPixelSize` is ignored on purpose here: no downsampling yet.
        let (data, _) = try await session.data(from: request.url)
        guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
        return image
    }
}
