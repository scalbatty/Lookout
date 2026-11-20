import CoreGraphics
import Domain
import Foundation
import Testing
@testable import GalleryFeature

struct MasonryLayoutTests {
    private func photo(_ id: String, width: Int, height: Int) -> Photo {
        Photo(id: PhotoID(rawValue: id), caption: nil, width: width, height: height, variants: [])
    }

    @Test(arguments: [(402.0, 2), (500.0, 3), (1024.0, 3)])
    func fitsColumnsOfAtLeastTheMinimumWidth(width: Double, count: Int) {
        let layout = MasonryLayout(width: width, spacing: 8)
        #expect(layout.columnCount == count)
        #expect(layout.columnWidth >= MasonryLayout.minColumnWidth)
    }

    @Test func cellsFollowThePhotoShapeWithinLimits() {
        let layout = MasonryLayout(width: 408, spacing: 8) // 2 columns of 192
        #expect(layout.size(for: photo("p", width: 3000, height: 4000)).height == 256)
        #expect(layout.size(for: photo("tall", width: 1000, height: 5000)).height == 384) // capped at 2:1 tall
        #expect(layout.size(for: photo("wide", width: 9000, height: 1000)).height == 96) // capped at 2:1 wide
    }

    @Test func eachPhotoGoesToTheShortestColumn() {
        let layout = MasonryLayout(width: 408, spacing: 8)
        let tall = photo("tall", width: 1000, height: 2000)
        let wide1 = photo("wide1", width: 2000, height: 1000)
        let wide2 = photo("wide2", width: 2000, height: 1000)
        let next = photo("next", width: 1000, height: 1000)

        let columns = layout.columns(for: [tall, wide1, wide2, next])

        // tall left; two wides stack on the right and stay shorter than tall.
        #expect(columns.map { $0.map(\.id.rawValue) } == [["tall"], ["wide1", "wide2", "next"]])
    }

    @Test func newPagesNeverMoveEarlierPhotos() {
        let layout = MasonryLayout(width: 500, spacing: 8)
        let photos = (0..<60).map { photo("\($0)", width: 1000 + ($0 * 337) % 2000, height: 1000 + ($0 * 211) % 2000) }

        let before = layout.columns(for: Array(photos.prefix(30)))
        let after = layout.columns(for: photos)

        for (old, new) in zip(before, after) {
            #expect(Array(new.prefix(old.count)) == old)
        }
    }

    @Test func heightsAreWhereTheNextCellGoes() {
        let layout = MasonryLayout(width: 408, spacing: 8) // 2 columns of 192
        let tall = photo("tall", width: 1000, height: 2000) // 384
        let wide = photo("wide", width: 2000, height: 1000) // 96

        #expect(layout.arrange([tall, wide]).heights == [392, 104])
        #expect(layout.arrange([]).heights == [0, 0])
    }

    @Test func placeholdersEndAllColumnsLevel() {
        let heights: [CGFloat] = [392, 104, 200]
        let tiles: [[CGFloat]] = [[100, 50], [80, 120], [60, 60]]

        let evened = MasonryLayout.evenedOut(tiles, below: heights)

        // The tallest column keeps its tiles; the others stretch their last one.
        #expect(evened == [[100, 50], [80, 358], [60, 282]])
        let ends = zip(heights, evened).map { $0 + $1.reduce(0, +) }
        #expect(Set(ends).count == 1)
    }
}
