import Foundation
import Testing
import Domain

struct PhotoTests {
    private func variant(_ width: Int) -> ImageVariant {
        ImageVariant(url: URL(string: "https://example.com/\(width).jpg")!, pixelWidth: width)
    }

    private func photo(width: Int = 4000, height: Int = 3000, variantWidths: [Int] = []) -> Photo {
        Photo(id: "id", caption: nil, width: width, height: height, variants: variantWidths.map(variant))
    }

    @Test(arguments: [
        (requested: 100, expected: 200),   // smaller than everything → smallest
        (requested: 200, expected: 200),   // exact match
        (requested: 390, expected: 400),   // in between → next size up
        (requested: 2000, expected: 1080), // larger than everything → largest
    ])
    func bestVariantPicksSmallestSufficientWidth(requested: Int, expected: Int) {
        // Deliberately unsorted: the source order must not matter.
        let photo = photo(variantWidths: [1080, 200, 400])
        #expect(photo.bestVariant(forPixelWidth: requested)?.pixelWidth == expected)
    }

    @Test func bestVariantIsNilWithoutVariants() {
        #expect(photo().bestVariant(forPixelWidth: 400) == nil)
    }

    @Test func aspectRatio() {
        #expect(photo(width: 4000, height: 2000).aspectRatio == 2)
    }

    @Test(arguments: [(width: 4000, height: 0), (width: 0, height: 3000), (width: 0, height: 0)])
    func aspectRatioFallsBackToSquareForMissingDimensions(width: Int, height: Int) {
        #expect(photo(width: width, height: height).aspectRatio == 1)
    }
}
