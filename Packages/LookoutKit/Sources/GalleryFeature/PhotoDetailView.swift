import Domain
import ImageLoading
import SwiftUI

/// A photo shown whole, on black, with its caption. Tapping toggles the
/// caption, navigation bar and status bar, for an unobstructed view; pinching
/// or double-tapping zooms in.
struct PhotoDetailView: View {
    /// How far the photo can be zoomed in, relative to fitting the screen.
    static let maximumZoomScale: CGFloat = 3
    /// Past this zoom, the fitted image looks soft: load one sized for
    /// `maximumZoomScale` instead.
    static let detailZoomThreshold: CGFloat = 1.5

    let photo: Photo
    let imageLoader: any ImageLoading

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var showsChrome = true
    /// Whether the photo was zoomed in enough to need a larger image. Stays
    /// set, so zooming back out keeps the sharper image rather than reloading.
    @State private var wantsDetail = false
    /// Whatever was already in memory when the view was created (usually the
    /// grid thumbnail). Taken once: looking it up on every render would swap
    /// it for the full image as soon as that one is cached, under the
    /// cross-fade, which shows as a flicker.
    @State private var placeholder: UIImage?

    init(photo: Photo, imageLoader: any ImageLoading) {
        self.photo = photo
        self.imageLoader = imageLoader
        _placeholder = State(initialValue: imageLoader.largestCachedImage(forAnyOf: photo.variants.map(\.url)))
    }

    var body: some View {
        GeometryReader { proxy in
            let pixelScale = displayScale * (wantsDetail ? Self.maximumZoomScale : 1)
            let request = photo.imageRequest(fitting: CGSize(
                width: proxy.size.width * pixelScale,
                height: proxy.size.height * pixelScale
            ))
            // The full image replaces the placeholder (cross-faded) once loaded.
            ZoomableImageView(
                image: image ?? placeholder,
                contentSize: fittedSize(in: proxy.size),
                maximumZoomScale: Self.maximumZoomScale,
                onZoomScaleChange: { scale in
                    if scale > Self.detailZoomThreshold { wantsDetail = true }
                },
                onSingleTap: {
                    withAnimation(.easeInOut(duration: 0.2)) { showsChrome.toggle() }
                }
            )
            .task(id: request) { await loadImage(request) }
        }
        .ignoresSafeArea()
        .background(.black)
        .overlay(alignment: .bottom) {
            if showsChrome {
                caption
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .toolbar(showsChrome ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .statusBarHidden(!showsChrome)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.accessibilityText)
        .accessibilityAddTraits(.isImage)
    }

    /// The photo's size when shown whole in `size`.
    private func fittedSize(in size: CGSize) -> CGSize {
        let ratio = CGFloat(photo.aspectRatio)
        guard size.width > 0, size.height > 0, ratio > 0 else { return size }
        return size.width / size.height < ratio
            ? CGSize(width: size.width, height: size.width / ratio)
            : CGSize(width: size.height * ratio, height: size.height)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            if photo.isSponsored {
                Text(localized("cell.sponsored"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            photo.captionText
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
