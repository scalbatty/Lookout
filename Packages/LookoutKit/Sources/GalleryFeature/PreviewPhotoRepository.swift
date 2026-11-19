#if DEBUG
import Domain

/// An offline `PhotoRepository` for previews, serving `PreviewPhotos` pages.
struct PreviewPhotoRepository: PhotoRepository {
    var latency: Duration = .zero
    /// How many pages exist; `nil` for an endless feed.
    var pageCount: Int?

    func editorialPhotos(page: Int) async throws -> Page<Photo> {
        try await self.page(page)
    }

    func searchPhotos(matching query: SearchQuery, page: Int) async throws -> Page<Photo> {
        try await self.page(page)
    }

    private func page(_ number: Int) async throws -> Page<Photo> {
        try await Task.sleep(for: latency)
        if let pageCount, number > pageCount {
            return Page(items: [], hasMore: false)
        }
        return Page(items: PreviewPhotos.page(number), hasMore: pageCount.map { number < $0 } ?? true)
    }
}
#endif
