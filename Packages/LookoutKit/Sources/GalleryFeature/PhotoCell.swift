import Domain
import ImageLoading
import SwiftUI

/// A grid cell: the photo filling the size the layout gives it, its caption, and a
/// "Sponsored" badge when relevant.
///
/// The image is loaded for the cell's exact pixel size, cancelled if the
/// cell disappears before it arrives, and released when the cell leaves the
/// screen; the image loader's cache, not the cell, keeps images around.
struct PhotoCell: View {
    let photo: Photo
    /// The cell's size, in points. Given by the grid so cells don't measure themselves.
    let size: CGSize
    let imageLoader: any ImageLoading
    /// Where the zoom transition to the full-screen photo starts, if any.
    var transitionNamespace: Namespace.ID?
    /// Shifts the loading pulse, so it travels across the grid as the
    /// placeholder tiles' does (`row + column`).
    var wave = 0

    @Environment(\.displayScale) private var displayScale
    /// Holds the image while the cell is on screen, so it stays even if the
    /// cache evicts it meanwhile.
    @State private var image: UIImage?
    /// The load failed: the placeholder stays, but stops breathing.
    @State private var failed = false

    private var imageRequest: ImageRequest? {
        photo.gridImageRequest(size: size, displayScale: displayScale)
    }

    /// An image already in memory is shown in the cell's very first frame,
    /// with no placeholder and no fade.
    private var displayedImage: UIImage? {
        image ?? imageRequest.flatMap(imageLoader.cachedImage(for:))
    }

    var body: some View {
        Rectangle()
            .fill(.clear)
            // Breathes like the grid's placeholder tiles while loading.
            .background {
                if displayedImage == nil {
                    Rectangle()
                        .fill(.tertiary)
                        .breathing(wave: wave, isActive: !failed)
                }
            }
            .overlay {
                if let displayedImage {
                    Image(uiImage: displayedImage)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            // The zoom starts from the image alone: the caption and badge
            // drawn over it don't exist on the full-screen side.
            .zoomTransitionSource(id: photo.id, in: transitionNamespace)
            .overlay(alignment: .bottomLeading) { caption }
            .overlay(alignment: .topLeading) { sponsoredBadge }
            .frame(width: size.width, height: size.height)
            .clipped()
            // Only images that arrive after the first frame fade in.
            .animation(.easeOut(duration: 0.2), value: displayedImage != nil)
            .task(id: imageRequest) { await loadImage() }
            .onDisappear { image = nil }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(photo.accessibilityText)
            .accessibilityAddTraits(.isImage)
    }

    private var caption: some View {
        photo.captionText
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .lineLimit(2)
            .lineSpacing(-1)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .bottom) {
                // A fixed height, so the scrim is as dark under the text in
                // a tall cell as in a short one.
                Self.scrim
                    .frame(height: 90)
                    .allowsHitTesting(false)
            }
    }

    /// Black easing in from the top: barely there at first, dense under the
    /// text, with no visible edge. Keeps white text legible on bright
    /// photos without dimming the rest. A plain fill, cheap to draw on
    /// every cell (unlike a shadow or blur).
    private static let scrim = LinearGradient(
        stops: stride(from: 0.0, through: 1.0, by: 0.125).map { location in
            // Ease-in (cubic): opacity grows slowly, then quickly near the bottom.
            .init(color: .black.opacity(0.75 * pow(location, 2.2)), location: location)
        },
        startPoint: .top,
        endPoint: .bottom
    )

    @ViewBuilder
    private var sponsoredBadge: some View {
        if photo.isSponsored {
            Text(localized("cell.sponsored"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.6), in: .capsule)
                .padding(8)
        }
    }

    private func loadImage() async {
        guard let imageRequest else { return }
        if let cached = imageLoader.cachedImage(for: imageRequest) {
            image = cached
            return
        }
        // Failures and cancellation leave the placeholder in place.
        failed = false
        let loaded = try? await imageLoader.image(for: imageRequest)
        // The cell may have left the screen meanwhile: don't hold on to the image.
        guard !Task.isCancelled else { return }
        image = loaded
        failed = loaded == nil
    }
}

#if DEBUG
@MainActor
private func previewCell(_ photo: Photo, loader: any ImageLoading = GeneratedImageLoader()) -> some View {
    PhotoCell(photo: photo, size: CGSize(width: 180, height: 240), imageLoader: loader).padding()
}

#Preview("Loaded") { previewCell(PreviewPhotos.landscape) }
#Preview("Portrait") { previewCell(PreviewPhotos.portrait) }
#Preview("Slow loading") { previewCell(PreviewPhotos.landscape, loader: GeneratedImageLoader(latency: .seconds(2))) }
#Preview("Load failure") { previewCell(PreviewPhotos.landscape, loader: GeneratedImageLoader(failing: URLError(.notConnectedToInternet))) }
#Preview("No caption") { previewCell(PreviewPhotos.noCaption) }
#Preview("Sponsored") { previewCell(PreviewPhotos.sponsored) }
#Preview("Long caption") { previewCell(PreviewPhotos.longCaption) }
#endif
