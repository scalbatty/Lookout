import Foundation
import UIKit

/// An offline `ImageLoading` for previews and tests: draws a colored image
/// instead of downloading. The same URL always gets the same color.
public struct GeneratedImageLoader: ImageLoading {
    /// Simulated loading time, to see placeholders and transitions in previews.
    private let latency: Duration
    private let failure: (any Error)?

    public init(latency: Duration = .zero, failing failure: (any Error)? = nil) {
        self.latency = latency
        self.failure = failure
    }

    public func image(for request: ImageRequest) async throws -> UIImage {
        if latency > .zero {
            try await Task.sleep(for: latency)
        }
        try Task.checkCancellation()
        if let failure { throw failure }

        let side = CGFloat(max(request.maxPixelSize, 1))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let hue = Self.hue(for: request.url)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let colors = [
                UIColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1).cgColor,
                UIColor(hue: hue, saturation: 0.75, brightness: 0.45, alpha: 1).cgColor,
            ]
            let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: side, y: side), options: [])
        }
    }

    /// A stable hue derived from the URL (Swift's `hashValue` changes between launches).
    static func hue(for url: URL) -> CGFloat {
        let sum = url.absoluteString.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return CGFloat(sum % 360) / 360
    }
}
