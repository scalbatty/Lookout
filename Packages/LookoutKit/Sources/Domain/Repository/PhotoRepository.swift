/// Where photos come from. Implemented by a concrete source (e.g. Unsplash)
/// and injected into features, which never see the source itself.
///
/// Pages are 1-based. Methods throw `DomainError`, or `CancellationError`
/// when the calling task is cancelled.
public protocol PhotoRepository: Sendable {
    /// A page of the editorial feed.
    func editorialPhotos(page: Int) async throws -> Page<Photo>

    /// A page of photos matching `query`.
    func searchPhotos(matching query: SearchQuery, page: Int) async throws -> Page<Photo>
}
