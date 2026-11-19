import SwiftUI

extension Shape where Self == RoundedRectangle {
    /// The shape of a grid tile: photo cells, their placeholders, and the
    /// start of the zoom transition, so all three always match.
    static var tile: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }
}
