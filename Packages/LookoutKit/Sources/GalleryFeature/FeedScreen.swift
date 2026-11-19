import Domain
import ImageLoading
import SwiftUI

/// The editorial feed: an endless grid of photos.
public struct FeedScreen: View {
    @State private var model: PhotoGridModel
    @State private var path: [Photo] = []
    @Namespace private var zoomNamespace
    private let imageLoader: any ImageLoading

    public init(repository: any PhotoRepository, imageLoader: any ImageLoading) {
        _model = State(initialValue: PhotoGridModel { page in
            try await repository.editorialPhotos(page: page)
        })
        self.imageLoader = imageLoader
    }

    public var body: some View {
        NavigationStack(path: $path) {
            PhotoGrid(
                model: model,
                imageLoader: imageLoader,
                onSelect: { path.append($0) },
                transitionNamespace: zoomNamespace
            ) {
                ContentUnavailableView {
                    Label { Text(localized("feed.empty.title")) } icon: { Image(systemName: "photo.on.rectangle") }
                } description: {
                    Text(localized("feed.empty.message"))
                }
            }
            .navigationTitle(Text(localized("feed.title")))
            .navigationDestination(for: Photo.self) { photo in
                PhotoDetailView(photo: photo, imageLoader: imageLoader)
                    .zoomTransitionDestination(id: photo.id, in: zoomNamespace)
            }
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
