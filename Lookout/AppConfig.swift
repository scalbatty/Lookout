import Foundation

/// Environment-specific configuration, read from the app's Info.plist.
///
/// Values are injected at build time from `Config/Lookout.xcconfig`, which
/// optionally includes the gitignored `Config/Secrets.xcconfig`.
struct AppConfig {
    /// The Unsplash Access Key, or `nil` when it was not configured.
    let unsplashAccessKey: String?

    init(bundle: Bundle = .main) {
        // An unset xcconfig variable still produces an empty string in Info.plist.
        let key = bundle.object(forInfoDictionaryKey: "UnsplashAccessKey") as? String
        unsplashAccessKey = (key?.isEmpty == false) ? key : nil
    }
}
