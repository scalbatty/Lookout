import Domain
import ImageLoading
import SwiftUI

/// The editorial feed: an endless grid of photos, searchable. Search
/// results replace the feed in the same grid while the field has a query;
/// the feed keeps its place underneath.
public struct FeedScreen: View {
    @State private var model: PhotoGridModel
    @State private var search: SearchModel
    @State private var searchText = ""
    @State private var path: [Photo] = []
    @Namespace private var zoomNamespace
    private let imageLoader: any ImageLoading

    public init(repository: any PhotoRepository, imageLoader: any ImageLoading) {
        _model = State(initialValue: PhotoGridModel { page in
            try await repository.editorialPhotos(page: page)
        })
        _search = State(initialValue: SearchModel(repository: repository))
        self.imageLoader = imageLoader
    }

    public var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let results = search.results, let query = search.query {
                    PhotoGrid(
                        model: results,
                        imageLoader: imageLoader,
                        onSelect: { path.append($0) },
                        transitionNamespace: zoomNamespace
                    ) {
                        ContentUnavailableView.search(text: query.text)
                    }
                    // A new query starts at the top, with a fresh grid.
                    .id(query)
                    // Scrolling the results means reading, not typing.
                    .scrollDismissesKeyboard(.immediately)
                } else {
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
                }
            }
            .navigationTitle(Text(localized("feed.title")))
            .searchable(text: $searchText, prompt: Text(localized("search.prompt")))
            .minimizedSearch()
            // Each keystroke cancels the previous task, which is what lets
            // the model wait for a pause in typing.
            .task(id: searchText) { await search.update(for: searchText) }
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
