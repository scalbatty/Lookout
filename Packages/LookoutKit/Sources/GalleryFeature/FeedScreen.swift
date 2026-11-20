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
    @State private var isSearchPresented = false
    /// How far each grid has scrolled from its top; the header scrolls away with it.
    @State private var feedScroll: CGFloat = 0
    @State private var resultsScroll: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
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

    private var isSearching: Bool { search.results != nil }

    private var hasBottomSearch: Bool {
        if #available(iOS 26, *) { true } else { false }
    }

    private var showsNavigationBar: Bool { !hasBottomSearch && isSearchPresented }

    /// iOS 26 has its own search button; earlier versions get one in the header.
    private var searchButtonAction: (() -> Void)? {
        hasBottomSearch ? nil : { isSearchPresented = true }
    }

    public var body: some View {
        NavigationStack(path: $path) {
            // The feed stays mounted under the results, so closing search
            // returns to the same scroll position.
            ZStack {
                PhotoGrid(
                    model: model,
                    imageLoader: imageLoader,
                    onSelect: { path.append($0) },
                    // One zoom source per photo: the visible grid's.
                    transitionNamespace: isSearching ? nil : zoomNamespace
                ) {
                    ContentUnavailableView {
                        Label { Text(localized("feed.empty.title")) } icon: { Image(systemName: "photo.on.rectangle") }
                    } description: {
                        Text(localized("feed.empty.message"))
                    }
                }
                .trackingScrollOffset($feedScroll)
                .opacity(isSearching ? 0 : 1)
                .allowsHitTesting(!isSearching)
                .accessibilityHidden(isSearching)

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
                    .trackingScrollOffset($resultsScroll)
                    .id(query)
                    // Scrolling the results means reading, not typing.
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .background(Color.paper)
            .safeAreaInset(edge: .top, spacing: 0) {
                FeedHeader(query: search.query?.text, onSearch: searchButtonAction)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                    // Moves up exactly as far as the content, until it's gone.
                    .offset(y: -min(max(isSearching ? resultsScroll : feedScroll, 0), headerHeight))
            }
            // Paper behind the status bar, so the header and photos pass
            // under it instead of under the clock.
            .overlay(alignment: .top) {
                Color.paper
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 0)
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
                PhotoDetailView(photo: photo, imageLoader: imageLoader)
                    .zoomTransitionDestination(id: photo.id, in: zoomNamespace)
            }
        }
        // Dark only: photos read best on a dark page, and the zoom into the
        // black full-screen view doesn't flash from a light background.
        .preferredColorScheme(.dark)
    }
}

private extension View {
    /// Reports how far the scroll view inside has moved from its top.
    /// Before iOS 18 there's no way to read it from outside, so the
    /// header stays put.
    @ViewBuilder
    func trackingScrollOffset(_ offset: Binding<CGFloat>) -> some View {
        if #available(iOS 18, *) {
            onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in
                offset.wrappedValue = new
            }
        } else {
            self
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
