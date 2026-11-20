/// One page of results from a paginated source.
public struct Page<Item: Sendable>: Sendable {
    public let items: [Item]
    /// Whether requesting the next page may return more items.
    public let hasMore: Bool

    public init(items: [Item], hasMore: Bool) {
        self.items = items
        self.hasMore = hasMore
    }
}

extension Page: Equatable where Item: Equatable {}
