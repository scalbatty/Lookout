import Domain
import ImageLoading
import SwiftUI

/// A photo shown whole, on black, with its caption. Tapping toggles the
/// caption, navigation bar and status bar, for an unobstructed view.
struct PhotoDetailView: View {
    let photo: Photo
    let imageLoader: any ImageLoading

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var showsChrome = true

    var body: some View {
        GeometryReader { proxy in
            let request = photo.imageRequest(fitting: CGSize(
                width: proxy.size.width * displayScale,
                height: proxy.size.height * displayScale
            ))
            photoView
                .frame(width: proxy.size.width, height: proxy.size.height)
                .task(id: request) { await loadImage(request) }
        }
        .ignoresSafeArea()
        .background(.black)
        .overlay(alignment: .bottom) {
            if showsChrome {
                caption.transition(.opacity)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { showsChrome.toggle() }
        }
        .toolbar(showsChrome ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .statusBarHidden(!showsChrome)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(captionText)
        .accessibilityAddTraits(.isImage)
    }

    /// Reserves the photo's shape while loading, so the zoom transition and
    /// the image share the same frame.
    private var photoView: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .aspectRatio(photo.aspectRatio, contentMode: .fit)
            .clipped()
            .animation(.easeOut(duration: 0.25), value: image != nil)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            if photo.isSponsored {
                Text(localized("cell.sponsored"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            captionText
                .font(.body)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 48)
        .padding(.bottom, 16)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    private var captionText: Text {
        if let caption = photo.caption {
            Text(caption)
        } else {
            Text(localized("cell.caption.placeholder")).italic()
        }
    }

    private func loadImage(_ request: ImageRequest?) async {
        guard let request else { return }
        let loaded = try? await imageLoader.image(for: request)
        guard !Task.isCancelled, let loaded else { return }
        image = loaded
    }
}

#if DEBUG
#Preview("Landscape") {
    NavigationStack {
        PhotoDetailView(photo: PreviewPhotos.landscape, imageLoader: GeneratedImageLoader(latency: .seconds(1)))
    }
}

#Preview("Portrait, sponsored") {
    NavigationStack {
        PhotoDetailView(photo: PreviewPhotos.sponsored, imageLoader: GeneratedImageLoader())
    }
}

#Preview("No caption") {
    NavigationStack {
        PhotoDetailView(photo: PreviewPhotos.noCaption, imageLoader: GeneratedImageLoader())
    }
}
#endif
