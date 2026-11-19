import Domain

/// What a photo grid shows, already in the shape the view draws.
/// Combinations the screen can't display (e.g. an error page over photos)
/// can't be represented.
public enum PhotoGridState: Equatable {
    /// First page in flight: placeholder cells.
    case loading
    /// First page failed: full-screen error.
    case failed(PhotoGridError)
    /// Loaded, nothing to show: the screen's own empty content.
    case empty
    case photos([Photo], footer: Footer)

    /// What appears below the photos.
    public enum Footer: Equatable {
        /// More to come, nothing in flight.
        case none
        /// Next page in flight.
        case loading
        /// Next page failed: inline error, photos stay visible.
        case failed(PhotoGridError)
        /// No more photos.
        case end
    }
}
