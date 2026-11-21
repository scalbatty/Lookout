import SwiftUI

/// The feed's masthead: a serif wordmark over a small-caps kicker.
///
/// Sits at the top of the grid and scrolls away with it.
struct FeedHeader: View {
    /// Shows a search button when set; used where search has no
    /// system entry point of its own (before iOS 26).
    var onSearch: (() -> Void)?

    @State private var showsAbout = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(localized("feed.title"))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(localized("feed.header.editorial"))
                    .font(.caption.weight(.semibold).smallCaps())
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            headerButton(localized("about.button"), systemImage: "info.circle") { showsAbout = true }
            if let onSearch {
                headerButton(localized("search.button"), systemImage: "magnifyingglass", action: onSearch)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showsAbout) {
            AboutView()
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
        }
    }

    private func headerButton(_ title: LocalizedStringResource, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(title) } icon: { Image(systemName: systemImage) }
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    /// The feed's warm off-white page; a warm near-black in Dark Mode.
    static let paper = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.065, blue: 0.06, alpha: 1)
            : UIColor(red: 0.965, green: 0.95, blue: 0.925, alpha: 1)
    })
}

#if DEBUG
#Preview("Editorial") {
    FeedHeader()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.paper)
}

#Preview("With search button") {
    FeedHeader(onSearch: {})
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.paper)
}

#Preview("Large type, dark") {
    FeedHeader(onSearch: {})
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.paper)
        .dynamicTypeSize(.accessibility2)
        .preferredColorScheme(.dark)
}
#endif
