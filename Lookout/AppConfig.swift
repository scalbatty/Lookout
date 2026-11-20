import Foundation

/// Environment-specific configuration, read from the app's Info.plist.
///
/// Values are injected at build time from `Config/Lookout.xcconfig`, which
/// optionally includes the gitignored `Config/Secrets.xcconfig`.
struct AppConfig {
    /// The Unsplash Access Key, or `nil` when it was not configured.
    let unsplashAccessKey: String?
    /// Replay recorded feed pages instead of calling Unsplash: reproducible
    /// profiling without spending request quota. Launch with
    /// `-ReplayRecordedFeed YES` (set in the scheme, or by Instruments).
    let replaysRecordedFeed: Bool
    /// Delay before each replayed page, to see loading states. Launch with
    /// `-ReplayLatency 3` (seconds).
    let replayLatency: Duration

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        replaysRecordedFeed = defaults.bool(forKey: "ReplayRecordedFeed")
        replayLatency = .seconds(defaults.double(forKey: "ReplayLatency"))
        // An unset xcconfig variable still produces an empty string in Info.plist.
        let key = bundle.object(forInfoDictionaryKey: "UnsplashAccessKey") as? String
        unsplashAccessKey = (key?.isEmpty == false) ? key : nil
    }
}
