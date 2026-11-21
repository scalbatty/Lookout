import Domain
import ImageLoading
import SwiftUI
import UIKit

/// The editorial feed: an endless grid of photos, searchable. Search
/// results replace the feed in the same grid while the field has a query;
/// the feed keeps its place underneath.
public struct FeedScreen: View {
    @State private var model: PhotoGridModel
    @State private var search: SearchModel
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var path: [Photo] = []
    /// The grid the shown photo was opened from, whose photos it pages through.
    @State private var openedGrid: PhotoGridModel?
    @Namespace private var zoomNamespace
    private let imageLoader: any ImageLoading

    public init(repository: any PhotoRepository, imageLoader: any ImageLoading) {
        _model = State(initialValue: PhotoGridModel { page in
            try await repository.editorialPhotos(page: page)
        })
        _search = State(initialValue: SearchModel(repository: repository))
        self.imageLoader = imageLoader
    }

    private var isSearching: Bool { search.results != nil }

    private var hasBottomSearch: Bool {
        if #available(iOS 26, *) { true } else { false }
    }

    private var showsNavigationBar: Bool { !hasBottomSearch && isSearchPresented }

    /// iOS 26 has its own search button; earlier versions get one in the header.
    private var searchButtonAction: (() -> Void)? {
        hasBottomSearch ? nil : { isSearchPresented = true }
    }

    /// Opens a photo full screen. The search field loses focus first: left
    /// focused, the system focuses it again, keyboard included, on the way back.
    private func open(_ photo: Photo, in grid: PhotoGridModel) {
        openedGrid = grid
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        path.append(photo)
    }

    public var body: some View {
        NavigationStack(path: $path) {
            // The feed stays mounted under the results, so closing search
            // returns to the same scroll position.
            ZStack {
                PhotoGrid(
                    model: model,
                    imageLoader: imageLoader,
                    onSelect: { open($0, in: model) },
                    // One zoom source per photo: the visible grid's.
                    transitionNamespace: isSearching ? nil : zoomNamespace
                ) {
                    // Scrolls away with the photos. Search results go without
                    // it: the search field already says what they are.
                    FeedHeader(onSearch: searchButtonAction)
                } emptyContent: {
                    ContentUnavailableView {
                        Label { Text(localized("feed.empty.title")) } icon: { Image(systemName: "photo.on.rectangle") }
                    } description: {
                        Text(localized("feed.empty.message"))
                    }
                }
                .opacity(isSearching ? 0 : 1)
                .allowsHitTesting(!isSearching)
                .accessibilityHidden(isSearching)

                if let results = search.results, let query = search.query {
                    PhotoGrid(
                        model: results,
                        imageLoader: imageLoader,
                        onSelect: { open($0, in: results) },
                        transitionNamespace: zoomNamespace
                    ) {
                        ContentUnavailableView.search(text: query.text)
                    }
                    // A new query starts at the top, with a fresh grid.
                    .id(query)
                    // Scrolling the results means reading, not typing.
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .background(Color.paper)
            // Photos scroll on under the notch; a short fade from the page
            // colour keeps the clock and battery readable over bright ones.
            .overlay(alignment: .top) {
                LinearGradient(colors: [Color.paper.opacity(0.85), Color.paper.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 0)
                    .allowsHitTesting(false)
            }
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: Text(localized("search.prompt")))
            .minimizedSearch()
            // The masthead replaces the system bar. Before iOS 26 the search
            // field lives in that bar, so it comes back while searching.
            .toolbar(showsNavigationBar ? .visible : .hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            // Each keystroke cancels the previous task, which is what lets
            // the model wait for a pause in typing.
            .task(id: searchText) { await search.update(for: searchText) }
            .navigationDestination(for: Photo.self) { photo in
                PhotoDetailView(
                    photo: photo,
                    grid: openedGrid ?? model,
                    imageLoader: imageLoader,
                    transitionNamespace: zoomNamespace
                )
            }
        }
        // Dark only: photos read best on a dark page, and the zoom into the
        // black full-screen view doesn't flash from a light background.
        .preferredColorScheme(.dark)
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
