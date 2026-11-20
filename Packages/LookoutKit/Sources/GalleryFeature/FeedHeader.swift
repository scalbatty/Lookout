import SwiftUI

/// The feed's masthead: a serif wordmark over a small-caps kicker that
/// names what the grid is showing — the editorial feed, or a search.
///
/// Sits on a material that fades into the photos scrolling under it.
struct FeedHeader: View {
    /// The search being shown, or `nil` for the editorial feed.
    var query: String?
    /// Shows a search button when set; used where search has no
    /// system entry point of its own (before iOS 26).
    var onSearch: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAbout = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(localized("feed.title"))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                kicker
                    .font(.caption.weight(.semibold).smallCaps())
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
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
        .background {
            Rectangle()
                .fill(Color.paper)
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                }
                .ignoresSafeArea(edges: .top)
        }
        .animation(reduceMotion ? nil : .smooth, value: query)
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

    private var kicker: Text {
        if let query {
            Text(localized("feed.header.searching \(query)"))
        } else {
            Text(localized("feed.header.editorial"))
        }
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

#Preview("Searching, with button") {
    FeedHeader(query: "mountains", onSearch: {})
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
