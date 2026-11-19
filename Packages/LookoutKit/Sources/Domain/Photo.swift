/// A photo as Lookout understands it, independent of where it comes from.
public struct Photo: Identifiable, Hashable, Sendable {
    public let id: String
    /// Short text describing the photo, if the source provided any.
    public let caption: String?
    /// Original dimensions, in pixels.
    public let width: Int
    public let height: Int
    /// Available renditions of the photo, in any order.
    public let variants: [ImageVariant]

    public init(id: String, caption: String?, width: Int, height: Int, variants: [ImageVariant]) {
        self.id = id
        self.caption = caption
        self.width = width
        self.height = height
        self.variants = variants
    }

    /// Width divided by height. Lets layouts reserve space before the image loads.
    public var aspectRatio: Double {
        guard height > 0 else { return 1 }
        return Double(width) / Double(height)
    }
}
