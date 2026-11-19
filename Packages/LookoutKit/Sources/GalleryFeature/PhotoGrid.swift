import Domain
import ImageLoading
import SwiftUI

/// A 2-column grid of photos with endless scrolling. Shared by the feed and
/// search: what it shows comes entirely from its model.
public struct PhotoGrid<EmptyContent: View>: View {
    private let model: PhotoGridModel
    private let imageLoader: any ImageLoading
    private let onSelect: (Photo) -> Void
    private let emptyContent: EmptyContent

    private let spacing: CGFloat = 8

    public init(
        model: PhotoGridModel,
        imageLoader: any ImageLoading,
        onSelect: @escaping (Photo) -> Void,
        @ViewBuilder emptyContent: () -> EmptyContent
    ) {
        self.model = model
        self.imageLoader = imageLoader
        self.onSelect = onSelect
        self.emptyContent = emptyContent()
    }

    public var body: some View {
        // Measured once for the whole grid, so cells don't measure themselves.
        GeometryReader { proxy in
            content(cellSide: cellSide(forWidth: proxy.size.width))
        }
        .task { model.start() }
    }

    @ViewBuilder
    private func content(cellSide: CGFloat) -> some View {
        switch model.state {
        case .loading:
            placeholderGrid(cellSide: cellSide)
        case .failed(let error):
            PhotoGridErrorView(error: error, retry: model.retry)
        case .empty:
            emptyContent
        case .photos(let photos, let footer):
            ScrollView {
                LazyVGrid(columns: columns(cellSide: cellSide), spacing: spacing) {
                    Section {
                        ForEach(photos) { photo in
                            Button { onSelect(photo) } label: {
                                PhotoCell(photo: photo, side: cellSide, imageLoader: imageLoader)
                            }
                            .buttonStyle(.plain)
                            .onAppear { model.itemAppeared(photo.id) }
                        }
                    } footer: {
                        // Inside the lazy grid on purpose: only lazy containers wait
                        // until a view nears the screen before calling `onAppear`.
                        PhotoGridFooter(footer: footer, loadMore: model.footerAppeared, retry: model.retry)
                    }
                }
                .padding(spacing)
            }
        }
    }

    private func placeholderGrid(cellSide: CGFloat) -> some View {
        ScrollView {
            LazyVGrid(columns: columns(cellSide: cellSide), spacing: spacing) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: cellSide, height: cellSide)
                }
            }
            .padding(spacing)
        }
        .scrollDisabled(true)
        .accessibilityHidden(true)
    }

    private func columns(cellSide: CGFloat) -> [GridItem] {
        Array(repeating: GridItem(.fixed(cellSide), spacing: spacing), count: 2)
    }

    private func cellSide(forWidth width: CGFloat) -> CGFloat {
        max(((width - spacing * 3) / 2).rounded(.down), 0)
    }
}

/// The row below the photos. Each case is a distinct view, so when a load
/// ends and the row is still on screen, `.none` appears anew and asks for
/// the next page.
private struct PhotoGridFooter: View {
    let footer: PhotoGridState.Footer
    let loadMore: () -> Void
    let retry: () -> Void

    var body: some View {
        Group {
            switch footer {
            case .none:
                Color.clear
                    .frame(height: 1)
                    .onAppear(perform: loadMore)
            case .loading:
                ProgressView()
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
            case .end:
                Text(localized("grid.end"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, footer == .none ? 0 : 16)
        .padding(.horizontal)
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
