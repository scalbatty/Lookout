import SwiftUI

// The system zoom transition between a grid cell and the full-screen photo
// exists from iOS 18. On iOS 17 these modifiers do nothing and navigation
// uses the regular push.

extension View {
    /// Marks this view as where the zoom transition to `id` starts.
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        modifier(ZoomSource(id: AnyHashable(id), namespace: namespace))
    }

    /// Makes this destination zoom in from the source with the same `id`.
    func zoomTransitionDestination(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        modifier(ZoomDestination(id: AnyHashable(id), namespace: namespace))
    }
}

private struct ZoomSource: ViewModifier {
    let id: AnyHashable
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if #available(iOS 18, *), let namespace {
            content.matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(.tile)
            }
        } else {
            content
        }
    }
}

private struct ZoomDestination: ViewModifier {
    let id: AnyHashable
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if #available(iOS 18, *), let namespace {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
