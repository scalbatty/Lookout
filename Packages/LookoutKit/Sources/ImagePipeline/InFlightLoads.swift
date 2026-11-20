import ImageLoading
import os
import UIKit

/// Runs at most one load per request at a time, shared by everyone who asks
/// for it while it's in flight (a preload, a visible cell, the full-screen
/// view), so the same image is never downloaded twice at once.
///
/// Loads always run to completion: a grid image is a few dozen kilobytes,
/// and every photo of a page is preloaded anyway. Waiting callers get the
/// result when it arrives; a cell that left the screen meanwhile ignores it.
final class InFlightLoads: Sendable {
    typealias Load = @Sendable (ImageRequest) async throws -> UIImage

    // Not `Mutex` (Synchronization): it requires iOS 18, and we support iOS 17.
    private let tasks = OSAllocatedUnfairLock<[ImageRequest: Task<UIImage, any Error>]>(initialState: [:])
    private let load: Load

    init(load: @escaping Load) {
        self.load = load
    }

    /// The image for `request`, joining the load in flight if there is one.
    func image(for request: ImageRequest) async throws -> UIImage {
        try await start(request, priority: Task.currentPriority).value
    }

    /// Starts low-priority loads nobody is waiting for yet.
    func prefetch(_ requests: [ImageRequest]) {
        for request in requests {
            _ = start(request, priority: .utility)
        }
    }

    /// Number of loads currently in flight. For tests.
    var count: Int { tasks.withLock { $0.count } }

    private func start(_ request: ImageRequest, priority: TaskPriority) -> Task<UIImage, any Error> {
        tasks.withLock { running in
            if let task = running[request] { return task }
            let task = Task(priority: priority) {
                defer { self.tasks.withLock { _ = $0.removeValue(forKey: request) } }
                return try await load(request)
            }
            running[request] = task
            return task
        }
    }
}
