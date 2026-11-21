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
    /// Called as a vertical pan at fit scale moves, with its translation.
    /// Zoomed in, pans move the image instead and this isn't called.
    var onPagePan: (CGFloat) -> Void = { _ in }
    /// Called when that pan ends, with its translation and velocity.
    var onPagePanEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void = { _, _ in }

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

        let pagePan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pagePanned))
        pagePan.delegate = context.coordinator
        // One finger only: the vertical motion of a pinch mustn't page.
        pagePan.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(pagePan)
        // A horizontal pan fails ours and goes to the scroll view (and the
        // system swipe back) as before.
        scrollView.panGestureRecognizer.require(toFail: pagePan)
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

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
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

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer,
                  let scrollView = pan.view as? UIScrollView,
                  scrollView.zoomScale <= scrollView.minimumZoomScale
            else { return false }
            let velocity = pan.velocity(in: scrollView)
            return abs(velocity.y) > abs(velocity.x)
        }

        @objc func pagePanned(_ pan: UIPanGestureRecognizer) {
            let translation = pan.translation(in: pan.view).y
            switch pan.state {
            case .changed:
                parent.onPagePan(translation)
            case .ended:
                parent.onPagePanEnded(translation, pan.velocity(in: pan.view).y)
            case .cancelled, .failed:
                parent.onPagePanEnded(0, 0)
            default:
                break
            }
        }

        @objc func singleTapped() {
            parent.onSingleTap()
        }

        @objc func doubleTapped(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? CenteringScrollView else { return }
            let animated = !UIAccessibility.isReduceMotionEnabled
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.zoom(to: scrollView.minimumZoomScale, centeredOn: nil, animated: animated)
            } else {
                let scale = min(ZoomableImageView.doubleTapZoomScale, scrollView.maximumZoomScale)
                scrollView.zoom(to: scale, centeredOn: recognizer.location(in: imageView), animated: animated)
            }
        }
    }
}

/// Keeps content smaller than the scroll view centred in it, rather than
/// pinned to the top-left corner.
private final class CenteringScrollView: UIScrollView {
    override func layoutSubviews() {
        super.layoutSubviews()
        // Past either limit (pinching beyond fit or beyond the maximum),
        // centre as if at that limit: the content then stays under the
        // fingers and the bounce back shrinks it in place, instead of
        // jumping to the middle first.
        let inset = centeringInset(at: min(max(zoomScale, minimumZoomScale), maximumZoomScale))
        if contentInset != inset { contentInset = inset }
    }

    /// The inset that centres the content at `scale`.
    private func centeringInset(at scale: CGFloat) -> UIEdgeInsets {
        let unscaled = CGSize(width: contentSize.width / zoomScale, height: contentSize.height / zoomScale)
        let horizontal = max(0, (bounds.width - unscaled.width * scale) / 2)
        let vertical = max(0, (bounds.height - unscaled.height * scale) / 2)
        return UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    /// Zooms to `scale`, with `point` (in the unzoomed content) as near the
    /// middle as the edges allow. Scale, inset and offset animate together:
    /// `zoom(to:animated:)` jumps the inset to its final value first, which
    /// shows as the image jumping before it zooms.
    func zoom(to scale: CGFloat, centeredOn point: CGPoint?, animated: Bool) {
        let inset = centeringInset(at: scale)
        let size = CGSize(width: contentSize.width / zoomScale * scale, height: contentSize.height / zoomScale * scale)
        let target = point ?? CGPoint(x: contentSize.width / zoomScale / 2, y: contentSize.height / zoomScale / 2)
        let offset = CGPoint(
            x: min(max(target.x * scale - bounds.width / 2, -inset.left), size.width - bounds.width + inset.right),
            y: min(max(target.y * scale - bounds.height / 2, -inset.top), size.height - bounds.height + inset.bottom)
        )
        let changes = {
            self.zoomScale = scale
            self.contentInset = inset
            self.contentOffset = offset
        }
        if animated {
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, animations: changes)
        } else {
            changes()
        }
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
