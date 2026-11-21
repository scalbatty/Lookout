import GalleryFeature
import ImagePipeline
import SwiftUI
import UnsplashAPI

@main
struct LookoutApp: App {
    /// Built once at launch. `nil` when there's no key (and no replay).
    private let repository: UnsplashPhotoRepository?
    /// Built once: it holds the memory cache and the disk cache's session.
    private let imageLoader = URLSessionImageLoader()

    init() {
        let config = AppConfig()
        if config.replaysRecordedFeed {
            let pages = (1...).lazy
                .map { Bundle.main.url(forResource: "editorial-page-\($0)", withExtension: "json") }
                .prefix { $0 != nil }
                .compactMap { $0 }
            repository = try? UnsplashPhotoRepository.replaying(recordedPages: Array(pages), latency: config.replayLatency)
        } else {
            repository = config.unsplashAccessKey.map { UnsplashPhotoRepository(accessKey: $0) }
        }
    }

    var body: some Scene {
        WindowGroup {
            // Composition root: the only place that knows the concrete
            // photo source and image loader.
            if let repository {
                FeedScreen(repository: repository, imageLoader: imageLoader)
            } else {
                MissingKeyView()
            }
        }
    }
}
