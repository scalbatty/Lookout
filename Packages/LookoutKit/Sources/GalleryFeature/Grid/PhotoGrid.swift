import Domain
import ImageLoading
import SwiftUI

/// A masonry grid of photos (2 or 3 columns) with endless scrolling. Shared by the feed and
/// search: what it shows comes entirely from its model.
public struct PhotoGrid<EmptyContent: View>: View {
    private let model: PhotoGridModel
    private let imageLoader: any ImageLoading
    private let onSelect: (Photo) -> Void
    private let transitionNamespace: Namespace.ID?
    private let emptyContent: EmptyContent

    private let spacing: CGFloat = 8

    @Environment(\.displayScale) private var displayScale
    /// Cells fully on screen. Not observed: only read when deciding to scroll.
    @State private var visibleIDs = VisibleIDs()

    public init(
        model: PhotoGridModel,
        imageLoader: any ImageLoading,
        onSelect: @escaping (Photo) -> Void,
        transitionNamespace: Namespace.ID? = nil,
        @ViewBuilder emptyContent: () -> EmptyContent
    ) {
        self.model = model
        self.imageLoader = imageLoader
        self.onSelect = onSelect
        self.transitionNamespace = transitionNamespace
        self.emptyContent = emptyContent()
    }

    public var body: some View {
        // Measured once for the whole grid, so cells don't measure themselves.
        GeometryReader { proxy in
            content(layout: MasonryLayout(width: proxy.size.width, spacing: spacing))
        }
        .task { model.start() }
    }

    @ViewBuilder
    private func content(layout: MasonryLayout) -> some View {
        switch model.state {
        case .loading:
            placeholderGrid(layout: layout)
        case .failed(let error):
            PhotoGridErrorView(error: error, retry: model.retry)
        case .empty:
            emptyContent
        case .photos(let photos, let footer):
            ScrollViewReader { scroller in
                ScrollView {
                    // The footer sits in a lazy stack on purpose: only lazy
                    // containers wait until a view nears the screen before
                    // calling `onAppear`.
                    LazyVStack(spacing: spacing) {
                        let arrangement = layout.arrange(photos)
                        let placeholders: [[CGFloat]] = if case .loading = footer {
                            placeholderHeights(below: arrangement.heights, rows: nextPagePlaceholderCount, layout: layout)
                        } else {
                            Array(repeating: [], count: layout.columnCount)
                        }
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(Array(arrangement.columns.enumerated()), id: \.offset) { columnIndex, column in
                                LazyVStack(spacing: spacing) {
                                    ForEach(Array(column.enumerated()), id: \.element.id) { row, photo in
                                        cell(for: photo, layout: layout, wave: row + columnIndex)
                                    }
                                    // While the next page loads, each column carries on
                                    // right under its own last photo, all ending level.
                                    ForEach(Array(placeholders[columnIndex].enumerated()), id: \.offset) { index, height in
                                        PlaceholderTile(
                                            size: CGSize(width: layout.columnWidth, height: height),
                                            wave: index + columnIndex
                                        )
                                        .accessibilityHidden(true)
                                    }
                                }
                                .frame(width: layout.columnWidth)
                            }
                        }
                        PhotoGridFooter(
                            footer: footer,
                            loadMore: model.footerAppeared,
                            retry: model.retry
                        )
                    }
                    .padding(spacing)
                }
                // Follows the photo shown full screen, out of sight under it, so
                // its cell is there for the zoom back.
                .onChange(of: model.shownPhotoID) { _, id in
                    if let id, !visibleIDs.contains(id) { scroller.scrollTo(id, anchor: .center) }
                }
            }
            // Each new page's images are preloaded as soon as it arrives, so
            // they're usually ready before their cells scroll into view. Lists
            // only grow: on the first call (equal counts) or for a new, shorter
            // list, everything is new.
            .onChange(of: photos.count, initial: true) { oldCount, newCount in
                let firstNew = oldCount < newCount ? oldCount : 0
                imageLoader.prefetch(photos[firstNew...].compactMap {
                    $0.gridImageRequest(size: layout.size(for: $0), displayScale: displayScale)
                })
            }
        }
    }

    private func cell(for photo: Photo, layout: MasonryLayout, wave: Int) -> some View {
        Button { onSelect(photo) } label: {
            PhotoCell(
                photo: photo,
                size: layout.size(for: photo),
                imageLoader: imageLoader,
                transitionNamespace: transitionNamespace,
                wave: wave
            )
        }
        .buttonStyle(PressableCellStyle())
        .onAppear { model.itemAppeared(photo.id) }
        .trackingVisibility(of: photo.id, in: visibleIDs)
    }

    private func placeholderGrid(layout: MasonryLayout) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            let columns = placeholderHeights(
                below: Array(repeating: 0, count: layout.columnCount),
                rows: 5,
                layout: layout
            )
            ForEach(Array(columns.enumerated()), id: \.offset) { column, heights in
                VStack(spacing: spacing) {
                    ForEach(Array(heights.enumerated()), id: \.offset) { row, height in
                        PlaceholderTile(
                            size: CGSize(width: layout.columnWidth, height: height),
                            wave: row + column
                        )
                    }
                }
            }
        }
        .padding(spacing)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// The IDs of the cells on screen, kept out of SwiftUI's observation so
/// scrolling doesn't re-render the grid.
private final class VisibleIDs {
    private var ids: Set<Photo.ID> = []
    func contains(_ id: Photo.ID) -> Bool { ids.contains(id) }
    func set(_ id: Photo.ID, visible: Bool) {
        if visible { ids.insert(id) } else { ids.remove(id) }
    }
}

private extension View {
    /// Before iOS 18 nothing is tracked, so the grid always scrolls.
    @ViewBuilder
    func trackingVisibility(of id: Photo.ID, in visibleIDs: VisibleIDs) -> some View {
        if #available(iOS 18, *) {
            onScrollVisibilityChange(threshold: 0.9) { visibleIDs.set(id, visible: $0) }
        } else {
            self
        }
    }
}

/// Placeholders added under each column while the next page loads: enough
/// to fill the bottom of the screen without making the scroll view much taller.
private let nextPagePlaceholderCount = 3

/// Heights of `rows` placeholders under columns of `heights`, varied like
/// photos, with the last of each column stretched so all columns end level.
private func placeholderHeights(below heights: [CGFloat], rows: Int, layout: MasonryLayout) -> [[CGFloat]] {
    let tiles = heights.indices.map { column in
        (0..<rows).map { row in
            placeholderSize(column: column, row: row, layout: layout).height
        }
    }
    return MasonryLayout.evenedOut(tiles, below: heights)
}

/// Heights for placeholder tiles, varied like real photos (portrait,
/// landscape, square), offset per column so the columns don't line up.
private let placeholderAspectRatios: [Double] = [0.75, 1.5, 1, 0.67, 1.33]

private func placeholderSize(column: Int, row: Int, layout: MasonryLayout) -> CGSize {
    let ratio = placeholderAspectRatios[(row + column * 2) % placeholderAspectRatios.count]
    return CGSize(width: layout.columnWidth, height: (layout.columnWidth / ratio).rounded())
}

/// The row below the photos. Each case is a distinct view, so when a load
/// ends and the row is still on screen, `.none` appears anew and asks for
/// the next page.
private struct PhotoGridFooter: View {
    let footer: PhotoGridState.Footer
    let loadMore: () -> Void
    let retry: () -> Void

    var body: some View {
        switch footer {
        case .none:
            Color.clear
                .frame(height: 1)
                .onAppear(perform: loadMore)
        case .loading:
            // The placeholders are at the end of each column instead.
            EmptyView()
        case .failed(let error):
            VStack(spacing: 8) {
                Text(error.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if error.isRetryable {
                    Button(action: retry) { Text(localized("grid.retry")) }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        case .end:
            Text(localized("grid.end"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
}

/// Stands in for a photo cell while photos load. Tiles breathe, with
/// `wave` (row + column) making the pulse travel diagonally across the grid.
struct PlaceholderTile: View {
    let size: CGSize
    var wave = 0

    var body: some View {
        Rectangle()
            .fill(.tertiary)
            .frame(width: size.width, height: size.height)
            .breathing(wave: wave)
    }
}

/// Full-screen error when the first page couldn't load.
private struct PhotoGridErrorView: View {
    let error: PhotoGridError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label { Text(localized("grid.error.title")) } icon: { Image(systemName: "photo.on.rectangle.angled") }
        } description: {
            Text(error.message)
        } actions: {
            if error.isRetryable {
                Button(action: retry) { Text(localized("grid.retry")) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#if DEBUG
@MainActor
private func previewGrid(_ loadPage: @escaping @Sendable (Int) async throws -> Page<Photo>) -> some View {
    PhotoGrid(
        model: PhotoGridModel(loadPage: loadPage),
        imageLoader: GeneratedImageLoader(latency: .milliseconds(300)),
        onSelect: { _ in },
        emptyContent: { ContentUnavailableView.search(text: "zebra crossing") }
    )
}

#Preview("Endless") {
    previewGrid { page in
        try await Task.sleep(for: .seconds(1))
        return Page(items: PreviewPhotos.page(page), hasMore: true)
    }
}

#Preview("First page loading") {
    previewGrid { _ in
        try await Task.sleep(for: .seconds(3600))
        return Page(items: [], hasMore: false)
    }
}

#Preview("First page failed") {
    previewGrid { _ in throw DomainError.offline }
}

#Preview("Not retryable") {
    previewGrid { _ in throw DomainError.unauthorized }
}

#Preview("Next page failed") {
    previewGrid { page in
        guard page == 1 else { throw DomainError.rateLimited }
        return Page(items: PreviewPhotos.page(page), hasMore: true)
    }
}

#Preview("End reached") {
    previewGrid { page in Page(items: PreviewPhotos.page(page), hasMore: false) }
}

#Preview("Empty") {
    previewGrid { _ in Page(items: [], hasMore: false) }
}
#endif
