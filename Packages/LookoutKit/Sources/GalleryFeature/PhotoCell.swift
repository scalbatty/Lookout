import Domain
import ImageLoading
import SwiftUI

/// A square grid cell: the photo cropped to fill, its caption, and a
/// "Sponsored" badge when relevant.
///
/// The image is loaded for the cell's exact pixel size, cancelled if the
/// cell disappears before it arrives, and released when the cell leaves the
/// screen; the image loader's cache, not the cell, keeps images around.
struct PhotoCell: View {
    let photo: Photo
    /// The cell's side, in points. Given by the grid so cells don't measure themselves.
    let side: CGFloat
    let imageLoader: any ImageLoading

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private var imageRequest: ImageRequest? {
        photo.imageRequest(fillingSquareOf: Int((side * displayScale).rounded(.up)))
    }

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomLeading) { caption }
            .overlay(alignment: .topLeading) { sponsoredBadge }
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
            .animation(.easeOut(duration: 0.2), value: image != nil)
            .task(id: imageRequest) { await loadImage() }
            .onDisappear { image = nil }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(.isImage)
    }

    private var caption: some View {
        captionText
            .font(.caption)
            .foregroundStyle(.white)
            .lineLimit(2)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .bottom) {
                // Keeps white text legible on bright photos.
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            }
    }

    private var captionText: Text {
        if let caption = photo.caption {
            Text(caption)
        } else {
            Text(localized("cell.caption.placeholder")).italic()
        }
    }

    @ViewBuilder
    private var sponsoredBadge: some View {
        if photo.isSponsored {
            Text(localized("cell.sponsored"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: .capsule)
                .padding(6)
        }
    }

    private var accessibilityText: Text {
        photo.isSponsored ? captionText + Text(verbatim: ", ") + Text(localized("cell.sponsored")) : captionText
    }

    private func loadImage() async {
        guard let imageRequest else { return }
        // Failures and cancellation leave the placeholder in place.
        let loaded = try? await imageLoader.image(for: imageRequest)
        // The cell may have left the screen meanwhile: don't hold on to the image.
        guard !Task.isCancelled else { return }
        image = loaded
    }
}

#if DEBUG
@MainActor
private func previewCell(_ photo: Photo, loader: any ImageLoading = GeneratedImageLoader()) -> some View {
    PhotoCell(photo: photo, side: 180, imageLoader: loader).padding()
}

#Preview("Loaded") { previewCell(PreviewPhotos.landscape) }
#Preview("Portrait") { previewCell(PreviewPhotos.portrait) }
#Preview("Slow loading") { previewCell(PreviewPhotos.landscape, loader: GeneratedImageLoader(latency: .seconds(2))) }
#Preview("Load failure") { previewCell(PreviewPhotos.landscape, loader: GeneratedImageLoader(failing: URLError(.notConnectedToInternet))) }
#Preview("No caption") { previewCell(PreviewPhotos.noCaption) }
#Preview("Sponsored") { previewCell(PreviewPhotos.sponsored) }
#Preview("Long caption") { previewCell(PreviewPhotos.longCaption) }
#endif
