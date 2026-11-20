import CoreGraphics
import Domain

/// Places photos in columns at their own shape, each photo going to the
/// shortest column so far (like Unsplash). Fits as many columns as are at
/// least `minColumnWidth` wide, between 2 and 3.
///
/// A photo's column depends only on the photos before it, so new pages
/// append below without moving photos already on screen.
struct MasonryLayout: Equatable {
    static let minColumnWidth: CGFloat = 150
    static let columnCounts = 2...3
    /// Cells are kept between 2:1 tall and 2:1 wide; photos beyond that are
    /// cropped to fit, so a panorama or a very tall shot doesn't dominate.
    static let aspectRatios = 0.5...2.0

    let columnCount: Int
    let columnWidth: CGFloat
    let spacing: CGFloat

    init(width: CGFloat, spacing: CGFloat) {
        let fitting = Int(((width - spacing) / (Self.minColumnWidth + spacing)).rounded(.down))
        columnCount = min(max(fitting, Self.columnCounts.lowerBound), Self.columnCounts.upperBound)
        columnWidth = max(((width - spacing * CGFloat(columnCount + 1)) / CGFloat(columnCount)).rounded(.down), 0)
        self.spacing = spacing
    }

    /// The cell size for `photo`: the column's width, and a height following
    /// the photo's shape within `aspectRatios`.
    func size(for photo: Photo) -> CGSize {
        let ratio = min(max(photo.aspectRatio, Self.aspectRatios.lowerBound), Self.aspectRatios.upperBound)
        return CGSize(width: columnWidth, height: (columnWidth / ratio).rounded())
    }

    /// `photos` split into `columnCount` columns, in order within each.
    func columns(for photos: [Photo]) -> [[Photo]] {
        arrange(photos).columns
    }

    /// `photos` split into columns, with each column's height so far: its
    /// cells and the spacing after each, i.e. where the next cell would go.
    func arrange(_ photos: [Photo]) -> (columns: [[Photo]], heights: [CGFloat]) {
        var columns = Array(repeating: [Photo](), count: columnCount)
        var heights = Array(repeating: CGFloat(0), count: columnCount)
        for photo in photos {
            // The first shortest column, so ties fill left to right.
            let shortest = heights.indices.min { heights[$0] < heights[$1] }!
            columns[shortest].append(photo)
            heights[shortest] += size(for: photo).height + spacing
        }
        return (columns, heights)
    }

    /// Placeholder tiles continuing columns of `heights`: each column gets its
    /// `tiles`, the last one stretched so every column ends on the same line.
    /// All columns need the same number of tiles.
    static func evenedOut(_ tiles: [[CGFloat]], below heights: [CGFloat]) -> [[CGFloat]] {
        let ends = zip(heights, tiles).map { $0 + $1.reduce(0, +) }
        let bottom = ends.max() ?? 0
        return zip(tiles, ends).map { column, end in
            guard let last = column.last else { return column }
            return column.dropLast() + [last + bottom - end]
        }
    }
}
