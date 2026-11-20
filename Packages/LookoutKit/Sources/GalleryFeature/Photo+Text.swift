import Domain
import SwiftUI

/// Text shared by the grid cell and the full-screen view, so they always
/// describe a photo the same way, on screen and to VoiceOver.
extension Photo {
    /// The caption, or an italic placeholder when the photo has none.
    var captionText: Text {
        if let caption {
            Text(caption)
        } else {
            Text(localized("cell.caption.placeholder")).italic()
        }
    }

    /// The caption, followed by "Sponsored" for paid placements.
    var accessibilityText: Text {
        isSponsored ? captionText + Text(verbatim: ", ") + Text(localized("cell.sponsored")) : captionText
    }
}
