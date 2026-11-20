import SwiftUI

/// A small card about the app and who made it, shown as a sheet from the
/// feed's masthead.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text(localized("feed.title"))
                .font(.system(.largeTitle, design: .serif, weight: .bold))
            Text(localized("about.tagline"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(localized("about.madeBy"))
                .font(.caption.weight(.semibold).smallCaps())
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
            // A person's name: never translated.
            Text(verbatim: "Pascal Batty")
                .font(.system(.title3, design: .serif))
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    Color.paper
        .sheet(isPresented: .constant(true)) {
            AboutView().presentationDetents([.height(260)])
        }
}

#Preview("Large type") {
    AboutView().dynamicTypeSize(.accessibility2)
}
#endif
