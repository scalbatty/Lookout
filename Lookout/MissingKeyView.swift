import SwiftUI

/// Shown at launch when no Unsplash Access Key was configured, instead of
/// a grid that would fail every request.
struct MissingKeyView: View {
    var body: some View {
        ContentUnavailableView {
            Label("missingKey.title", systemImage: "key.slash")
        } description: {
            Text("missingKey.message")
        }
    }
}

#Preview {
    MissingKeyView()
}
