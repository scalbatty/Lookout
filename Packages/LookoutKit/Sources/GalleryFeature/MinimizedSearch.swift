import SwiftUI

extension View {
    /// Shows search as a button in the bottom trailing corner that expands into a field, where the
    /// system supports it (iOS 26). Earlier versions keep the standard
    /// search bar under the title.
    @ViewBuilder
    func minimizedSearch() -> some View {
        if #available(iOS 26, *) {
            searchToolbarBehavior(.minimize)
                .toolbar {
                    // Pushes the button to the trailing corner.
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
        } else {
            self
        }
    }
}
