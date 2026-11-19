import Foundation
import ImageLoading
import UIKit

/// `ImageLoading` over `URLSession`: one download per request, decoded off
/// the main thread at the size it will be displayed at. Nothing is cached
/// beyond `URLSession`'s default behaviour yet.
public struct URLSessionImageLoader: ImageLoading {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// `@concurrent`: downloading and decoding never run on the caller's
    /// actor (the main actor, from views).
    @concurrent
    public func image(for request: ImageRequest) async throws -> UIImage {
        let (data, _) = try await session.data(from: request.url)
        try Task.checkCancellation()
        return try ImageDecoder.downsample(data, maxPixelSize: request.maxPixelSize)
    }
}
