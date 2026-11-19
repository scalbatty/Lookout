import GalleryFeature
import ImagePipeline
import SwiftUI
import UnsplashAPI

@main
struct LookoutApp: App {
    private let config = AppConfig()

    var body: some Scene {
        WindowGroup {
            // Composition root: the only place that knows the concrete
            // photo source and image loader.
            if let accessKey = config.unsplashAccessKey {
                FeedScreen(
                    repository: UnsplashPhotoRepository(accessKey: accessKey),
                    imageLoader: URLSessionImageLoader()
                )
            } else {
                MissingKeyView()
            }
        }
    }
}
