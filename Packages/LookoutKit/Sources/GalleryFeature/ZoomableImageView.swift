import SwiftUI
import UIKit

/// Shows `image` at `contentSize`, centred, with Photos-style zooming: pinch
/// (anchored under the fingers, bouncing past the limits), pan while zoomed,
/// and double-tap to zoom into a point or back to fit.
///
/// SwiftUI has no zoomable scroll view, so this wraps `UIScrollView`, which
/// also gives the zoom transition's swipe-to-dismiss the usual scroll view
/// arbitration: it only wins when the content can't scroll further. The
/// image sits in a plain `UIImageView`, so it's drawn on the first frame,
/// even mid-transition.
struct ZoomableImageView: UIViewRepresentable {
    /// `nil` shows a faint fill of the image's shape until it arrives.
    let image: UIImage?
    /// The image's size at fit scale, in points.
    let contentSize: CGSize
    let maximumZoomScale: CGFloat
    /// Called as the zoom scale changes, 1 being fit.
    var onZoomScaleChange: (CGFloat) -> Void = { _ in }
    /// Called on a single tap, once it's clear it isn't a double-tap.
    var onSingleTap: () -> Void = {}

    /// The scale a double-tap zooms to, as Photos does: close enough to see
    /// detail without being lost in the image.
    static let doubleTapZoomScale: CGFloat = 2.5

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = CenteringScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = context.coordinator.imageView
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = image == nil ? UIColor.white.withAlphaComponent(0.08) : nil
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.addSubview(imageView)
        scrollView.contentSize = contentSize

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped))
        doubleTap.numberOfTapsRequired = 2
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleTapped))
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(singleTap)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.maximumZoomScale = maximumZoomScale
        let imageView = context.coordinator.imageView
        if imageView.image !== image {
            // Cross-fade from the placeholder to the full image.
            let animated = imageView.image != nil && !UIAccessibility.isReduceMotionEnabled
            UIView.transition(with: imageView, duration: animated ? 0.25 : 0, options: .transitionCrossDissolve) {
                imageView.image = image
                imageView.backgroundColor = image == nil ? UIColor.white.withAlphaComponent(0.08) : nil
            }
        }
        // A new size (rotation) starts again from fit.
        if imageView.bounds.size != contentSize {
            scrollView.zoomScale = 1
            imageView.frame = CGRect(origin: .zero, size: contentSize)
            scrollView.contentSize = contentSize
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageView
        let imageView = UIImageView()

        init(parent: ZoomableImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            parent.onZoomScaleChange(scrollView.zoomScale)
        }

        @objc func singleTapped() {
            parent.onSingleTap()
        }

        @objc func doubleTapped(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView else { return }
            let animated = !UIAccessibility.isReduceMotionEnabled
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: animated)
                return
            }
            // Zoom into a rect centred on the tapped point (clamped to the
            // content's edges by the scroll view).
            let point = recognizer.location(in: imageView)
            let scale = min(ZoomableImageView.doubleTapZoomScale, scrollView.maximumZoomScale)
            let size = CGSize(width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
            let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
            scrollView.zoom(to: rect, animated: animated)
        }
    }
}

/// Keeps content smaller than the scroll view centred in it, rather than
/// pinned to the top-left corner.
private final class CenteringScrollView: UIScrollView {
    override func layoutSubviews() {
        super.layoutSubviews()
        // Below the minimum scale (pinching out past fit), centre as if at the
        // minimum: the content then stays under the fingers and only returns
        // to the middle with the bounce, instead of jumping there first.
        let scale = max(zoomScale, minimumZoomScale) / zoomScale
        let horizontal = max(0, (bounds.width - contentSize.width * scale) / 2)
        let vertical = max(0, (bounds.height - contentSize.height * scale) / 2)
        let inset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        if contentInset != inset { contentInset = inset }
    }
}

#if DEBUG
#Preview {
    ZoomableImageView(
        image: UIImage(systemName: "photo.artframe")?.withTintColor(.white, renderingMode: .alwaysOriginal),
        contentSize: CGSize(width: 300, height: 240),
        maximumZoomScale: 4
    )
    .background(.black)
    .ignoresSafeArea()
}
#endif
