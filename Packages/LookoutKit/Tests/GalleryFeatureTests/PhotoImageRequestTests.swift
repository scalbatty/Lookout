import Domain
import Foundation
import Testing
@testable import GalleryFeature

struct PhotoImageRequestTests {
    private func photo(width: Int, height: Int) -> Photo {
        Photo(id: "p", caption: nil, width: width, height: height, variants: [200, 400, 1080].map {
            ImageVariant(url: URL(string: "https://example.com/\($0)")!, pixelWidth: $0)
        })
    }

    @Test func squarePhotoUsesTheSide() {
        let request = photo(width: 1000, height: 1000).imageRequest(filling: CGSize(width: 400, height: 400))
        #expect(request?.maxPixelSize == 400)
        #expect(request?.url.lastPathComponent == "400")
    }

    @Test func portraitPhotoNeedsItsWidthToCoverTheSquare() {
        // 3:4 portrait in a 400 px square: 400 wide, 534 tall.
        let request = photo(width: 3000, height: 4000).imageRequest(filling: CGSize(width: 400, height: 400))
        #expect(request?.maxPixelSize == 534)
        #expect(request?.url.lastPathComponent == "400")
    }

    @Test func landscapePhotoNeedsItsHeightToCoverTheSquare() {
        // 4:3 landscape in a 400 px square: 534 wide, 400 tall.
        let request = photo(width: 4000, height: 3000).imageRequest(filling: CGSize(width: 400, height: 400))
        #expect(request?.maxPixelSize == 534)
        #expect(request?.url.lastPathComponent == "1080")
    }

    @Test func portraitPhotoInAPortraitCellOfTheSameShape() {
        // 3:4 photo in a 300×400 px cell: exactly 300 wide, 400 tall.
        let request = photo(width: 3000, height: 4000).imageRequest(filling: CGSize(width: 300, height: 400))
        #expect(request?.maxPixelSize == 400)
        #expect(request?.url.lastPathComponent == "400")
    }

    @Test func panoramaIsCappedAtTwiceTheSide() {
        // 10:1 in a 400 px square would need 4000 px wide; capped at 800.
        let request = photo(width: 10000, height: 1000).imageRequest(filling: CGSize(width: 400, height: 400))
        #expect(request?.maxPixelSize == 800)
        #expect(request?.url.lastPathComponent == "1080")
    }

    @Test func landscapeFittedInAPortraitScreenFillsTheWidth() {
        // 4:3 in a 1200×2600 px screen: 1200×900.
        let request = photo(width: 4000, height: 3000).imageRequest(fitting: CGSize(width: 1200, height: 2600))
        #expect(request?.maxPixelSize == 1200)
        #expect(request?.url.lastPathComponent == "1080") // largest available
    }

    @Test func tallPortraitFittedInAScreenFillsTheHeight() {
        // 1:4 in a 1200×2600 px screen: 650×2600.
        let request = photo(width: 1000, height: 4000).imageRequest(fitting: CGSize(width: 1200, height: 2600))
        #expect(request?.maxPixelSize == 2600)
        #expect(request?.url.lastPathComponent == "1080")
    }

    @Test func emptyBoxMeansNoRequest() {
        #expect(photo(width: 1, height: 1).imageRequest(fitting: .zero) == nil)
    }

    @Test func noVariantsMeansNoRequest() {
        let bare = Photo(id: "p", caption: nil, width: 1, height: 1, variants: [])
        #expect(bare.imageRequest(filling: CGSize(width: 400, height: 400)) == nil)
    }
}
