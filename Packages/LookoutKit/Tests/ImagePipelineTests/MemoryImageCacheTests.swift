import Foundation
import Testing
import UIKit
@testable import ImagePipeline

struct MemoryImageCacheTests {
    private let thumb = URL(string: "https://example.com/thumb.jpg")!
    private let regular = URL(string: "https://example.com/regular.jpg")!

    private func image(side: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    @Test func returnsTheExactSize() {
        let cache = MemoryImageCache()
        let small = image(side: 100)
        cache.insert(small, for: thumb, maxPixelSize: 100)

        #expect(cache.image(for: thumb, maxPixelSize: 100) === small)
        #expect(cache.image(for: thumb, maxPixelSize: 200) == nil)
        #expect(cache.image(for: regular, maxPixelSize: 100) == nil)
    }

    @Test func largestAcrossURLsAndSizes() {
        let cache = MemoryImageCache()
        let small = image(side: 100)
        let medium = image(side: 300)
        let large = image(side: 600)
        cache.insert(small, for: thumb, maxPixelSize: 100)
        cache.insert(medium, for: thumb, maxPixelSize: 300)
        cache.insert(large, for: regular, maxPixelSize: 600)

        #expect(cache.largestImage(forAnyOf: [thumb]) === medium)
        #expect(cache.largestImage(forAnyOf: [thumb, regular]) === large)
        #expect(cache.largestImage(forAnyOf: [URL(string: "https://example.com/none.jpg")!]) == nil)
    }

    @Test func costGrowsWithThePixelCount() {
        let small = MemoryImageCache.cost(of: image(side: 100))
        let large = MemoryImageCache.cost(of: image(side: 200))
        #expect(small >= 100 * 100 * 4) // RGBA, rows may be padded
        #expect(large > small * 3) // ~4×, minus row padding on the small one
    }
}
