import Foundation
import Testing
import UIKit
@testable import ImagePipeline

struct ImageDecoderTests {
    /// A 2000×1000 px JPEG.
    private let landscapeJPEG: Data = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000), format: format)
            .jpegData(withCompressionQuality: 0.8) { context in
                UIColor.orange.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
            }
    }()

    @Test func downsamplesToTheLongestEdge() throws {
        let image = try ImageDecoder.downsample(landscapeJPEG, maxPixelSize: 500)
        #expect(image.cgImage?.width == 500)
        #expect(image.cgImage?.height == 250)
    }

    @Test func neverUpscales() throws {
        let image = try ImageDecoder.downsample(landscapeJPEG, maxPixelSize: 4000)
        #expect(image.cgImage?.width == 2000)
    }

    @Test func rejectsDataThatIsNotAnImage() {
        #expect(throws: URLError.self) {
            try ImageDecoder.downsample(Data("not an image".utf8), maxPixelSize: 500)
        }
    }
}
