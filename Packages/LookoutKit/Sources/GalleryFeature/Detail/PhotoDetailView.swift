import Domain
import ImageLoading
import SwiftUI

/// A photo shown whole, on black, with its caption. Tapping toggles the
/// caption, navigation bar and status bar, for an unobstructed view; pinching
/// or double-tapping zooms in. Swiping up or down (at fit scale) or the toolbar
/// buttons move through the photos of the grid it was opened from.
struct PhotoDetailView: View {
    /// The grid the photo was opened from: its photos, in order, are the
    /// neighbours. Reporting the shown photo to it loads more near the end.
    let grid: PhotoGridModel
    let imageLoader: any ImageLoading
    /// Where the zoom transition comes from; follows the photo shown, so
    /// going back zooms into that photo's cell.
    var transitionNamespace: Namespace.ID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var photo: Photo
    @State private var showsChrome = true
    /// How far the current photo follows a vertical pan.
    @State private var dragOffset: CGFloat = 0
    /// +1 when moving to the next photo, -1 to the previous one.
    @State private var direction = 1

    init(photo: Photo, grid: PhotoGridModel, imageLoader: any ImageLoading, transitionNamespace: Namespace.ID? = nil) {
        _photo = State(initialValue: photo)
        self.grid = grid
        self.imageLoader = imageLoader
        self.transitionNamespace = transitionNamespace
    }

    private var photos: [Photo] {
        if case .photos(let items, _) = grid.state { items } else { [] }
    }

    /// The photo `step` places away from the one shown, if any.
    private func neighbour(_ step: Int) -> Photo? {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }),
              photos.indices.contains(index + step)
        else { return nil }
        return photos[index + step]
    }

    var body: some View {
        GeometryReader { proxy in
            PhotoPage(
                photo: photo,
                imageLoader: imageLoader,
                onSingleTap: {
                    withAnimation(.easeInOut(duration: 0.2)) { showsChrome.toggle() }
                },
                onPagePan: { offset in
                    direction = offset < 0 ? 1 : -1
                    // Resists past the first and last photos.
                    dragOffset = neighbour(direction) == nil ? offset / 3 : offset
                },
                onPagePanEnded: { offset, velocity in
                    let projected = offset + velocity * 0.2
                    let step = offset < 0 ? 1 : -1
                    if abs(projected) > proxy.size.height / 4, offset.sign == projected.sign {
                        show(step)
                    }
                    withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
                }
            )
            .offset(y: dragOffset)
            .id(photo.id)
            .transition(pageTransition)
            .task(id: photo.id) { await preloadNeighbours(fitting: proxy.size) }
        }
        .ignoresSafeArea()
        .background(.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.detailAccessibilityText)
        .accessibilityAddTraits(.isImage)
        // VoiceOver's three-finger swipe moves between photos too.
        .accessibilityScrollAction { edge in
            switch edge {
            case .top: show(-1)
            case .bottom: show(1)
            default: break
            }
        }
        .overlay(alignment: .bottom) {
            if showsChrome {
                caption
                    .allowsHitTesting(false)
                    // Already part of the photo's label.
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        // In the system bar, which places itself: at the top, or in the
        // side bar where the device has one (an iPhone Duo's outer screen).
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) { pagingButtons }
        }
        .toolbar(showsChrome ? .visible : .hidden, for: .navigationBar)
        .statusBarHidden(!showsChrome)
        .zoomTransitionDestination(id: photo.id, in: transitionNamespace)
        // Lets the grid keep this photo in view, and load its next page as
        // the end comes near.
        .onChange(of: photo.id, initial: true) {
            grid.itemAppeared(photo.id)
        }
        // Not on open: the tapped cell is already in view, and scrolling to
        // centre it would jump the grid under the zoom.
        .onChange(of: photo.id) { grid.shownPhotoID = photo.id }
        // Cleared so paging back to a previously shown photo still scrolls.
        .onDisappear { grid.shownPhotoID = nil }
    }

    /// Shows the photo `step` places away, sliding it in from below (next) or above.
    private func show(_ step: Int) {
        guard let next = neighbour(step) else { return }
        direction = step
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35)) {
            photo = next
            dragOffset = 0
        }
    }

    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: direction > 0 ? .bottom : .top),
            removal: .move(edge: direction > 0 ? .top : .bottom)
        )
    }

    /// Loads the screen-sized images of both neighbours, so paging shows
    /// them sharp straight away. Awaited rather than prefetched: moving on
    /// cancels this task, and with it the neighbours' downloads (megabytes
    /// each) unless the photo now shown needs them.
    private func preloadNeighbours(fitting size: CGSize) async {
        let pixels = CGSize(width: size.width * displayScale, height: size.height * displayScale)
        let requests = [neighbour(-1), neighbour(1)].compactMap { $0?.imageRequest(fitting: pixels) }
        let loader = imageLoader
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask { _ = try? await loader.image(for: request) }
            }
        }
    }

    @ViewBuilder
    private var pagingButtons: some View {
        Button { show(-1) } label: {
            Label { Text(localized("detail.previous")) } icon: { Image(systemName: "chevron.up") }
        }
        .disabled(neighbour(-1) == nil)
        Button { show(1) } label: {
            Label { Text(localized("detail.next")) } icon: { Image(systemName: "chevron.down") }
        }
        .disabled(neighbour(1) == nil)
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
            if let creator = photo.creatorName {
                Text(localized("detail.photoBy \(creator)"))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
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
}

/// One photo of the detail view: the grid thumbnail straight away, then an
/// image sized for the screen, zoomable.
private struct PhotoPage: View {
    /// How far the photo can be zoomed in, relative to fitting the screen.
    static let maximumZoomScale: CGFloat = 3
    /// Past this zoom, the fitted image looks soft: load one sized for
    /// `maximumZoomScale` instead.
    static let detailZoomThreshold: CGFloat = 1.5

    let photo: Photo
    let imageLoader: any ImageLoading
    let onSingleTap: () -> Void
    let onPagePan: (CGFloat) -> Void
    let onPagePanEnded: (CGFloat, CGFloat) -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    /// Whether the photo was zoomed in enough to need a larger image. Stays
    /// set, so zooming back out keeps the sharper image rather than reloading.
    @State private var wantsDetail = false
    /// Whatever was already in memory when the view was created (usually the
    /// grid thumbnail). Taken once: looking it up on every render would swap
    /// it for the full image as soon as that one is cached, under the
    /// cross-fade, which shows as a flicker.
    @State private var placeholder: UIImage?

    init(
        photo: Photo,
        imageLoader: any ImageLoading,
        onSingleTap: @escaping () -> Void,
        onPagePan: @escaping (CGFloat) -> Void,
        onPagePanEnded: @escaping (CGFloat, CGFloat) -> Void
    ) {
        self.photo = photo
        self.imageLoader = imageLoader
        self.onSingleTap = onSingleTap
        self.onPagePan = onPagePan
        self.onPagePanEnded = onPagePanEnded
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
                onSingleTap: onSingleTap,
                onPagePan: onPagePan,
                onPagePanEnded: onPagePanEnded
            )
            .task(id: request) { await loadImage(request) }
        }
    }

    /// The photo's size when shown whole in `size`.
    private func fittedSize(in size: CGSize) -> CGSize {
        let ratio = CGFloat(photo.aspectRatio)
        guard size.width > 0, size.height > 0, ratio > 0 else { return size }
        return size.width / size.height < ratio
            ? CGSize(width: size.width, height: size.width / ratio)
            : CGSize(width: size.height * ratio, height: size.height)
    }

    private func loadImage(_ request: ImageRequest?) async {
        guard let request else { return }
        let loaded = try? await imageLoader.image(for: request)
        guard !Task.isCancelled, let loaded else { return }
        image = loaded
    }
}

#if DEBUG
@MainActor
private func previewGrid() -> PhotoGridModel {
    let repository = PreviewPhotoRepository()
    let grid = PhotoGridModel { page in try await repository.editorialPhotos(page: page) }
    grid.start()
    return grid
}

#Preview("Landscape") {
    NavigationStack {
        PhotoDetailView(photo: PreviewPhotos.landscape, grid: previewGrid(), imageLoader: GeneratedImageLoader(latency: .seconds(1)))
    }
}

#Preview("Portrait, sponsored") {
    NavigationStack {
        PhotoDetailView(photo: PreviewPhotos.sponsored, grid: previewGrid(), imageLoader: GeneratedImageLoader())
    }
}

#Preview("No caption") {
    NavigationStack {
        PhotoDetailView(photo: PreviewPhotos.noCaption, grid: previewGrid(), imageLoader: GeneratedImageLoader())
    }
}
#endif
