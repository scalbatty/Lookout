import Domain
import ImageLoading
import SwiftUI

/// The editorial feed: an endless grid of photos.
public struct FeedScreen: View {
    @State private var model: PhotoGridModel
    private let imageLoader: any ImageLoading

    public init(repository: any PhotoRepository, imageLoader: any ImageLoading) {
        _model = State(initialValue: PhotoGridModel { page in
            try await repository.editorialPhotos(page: page)
        })
        self.imageLoader = imageLoader
    }

    public var body: some View {
        NavigationStack {
            PhotoGrid(model: model, imageLoader: imageLoader, onSelect: { _ in }) {
                ContentUnavailableView {
                    Label { Text(localized("feed.empty.title")) } icon: { Image(systemName: "photo.on.rectangle") }
                } description: {
                    Text(localized("feed.empty.message"))
                }
            }
            .navigationTitle(Text(localized("feed.title")))
        }
    }
}

#if DEBUG
#Preview("Feed") {
    FeedScreen(
        repository: PreviewPhotoRepository(latency: .seconds(1)),
        imageLoader: GeneratedImageLoader(latency: .milliseconds(300))
    )
}

#Preview("Empty feed") {
    FeedScreen(repository: PreviewPhotoRepository(pageCount: 0), imageLoader: GeneratedImageLoader())
}
#endif
