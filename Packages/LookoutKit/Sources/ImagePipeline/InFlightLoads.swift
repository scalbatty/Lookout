import Foundation
import ImageLoading
import os
import UIKit

/// Runs at most one load per request at a time, shared by everyone who asks
/// for it while it's in flight (a preload, a visible cell, the full-screen
/// view), so the same image is never downloaded twice at once.
///
/// Each load counts the callers awaiting it. When the last one is cancelled
/// (a cell left the screen, the full-screen view moved to another photo),
/// the load is cancelled too, after a short grace period in case someone
/// joins it again (paging to a photo hands its load from the neighbour
/// preload to the page itself, cancelling one before the other starts): full-screen images are megabytes, not worth
/// finishing for nobody. Preloads are the exception: they run to completion,
/// since a page's grid images are small and preloaded on purpose.
final class InFlightLoads: Sendable {
    typealias Load = @Sendable (ImageRequest) async throws -> UIImage

    private struct Entry {
        /// Tells this load apart from a later one for the same request.
        let id: UUID
        let task: Task<UIImage, any Error>
        var waiters = 0
        /// Started or joined by a preload: never cancelled.
        var isPinned = false
    }

    // Not `Mutex` (Synchronization): it requires iOS 18, and we support iOS 17.
    private let entries = OSAllocatedUnfairLock<[ImageRequest: Entry]>(initialState: [:])
    private let load: Load
    private let grace: Duration

    /// - Parameter grace: How long a load nobody waits for keeps running
    ///   before it's cancelled, so a caller arriving right after keeps it.
    init(grace: Duration = .milliseconds(300), load: @escaping Load) {
        self.grace = grace
        self.load = load
    }

    /// The image for `request`, joining the load in flight if there is one.
    ///
    /// Cancelling the caller cancels the load if nobody else awaits it and
    /// it isn't a preload. A cancelled caller still returns only once the
    /// load ends: right away when it was cancelled, else with its result.
    func image(for request: ImageRequest) async throws -> UIImage {
        let (id, task) = entries.withLock { entries in
            var entry = start(request, priority: Task.currentPriority, in: &entries)
            entry.waiters += 1
            entries[request] = entry
            return (entry.id, entry.task)
        }
        let hasLeft = OSAllocatedUnfairLock(initialState: false)
        defer { leave(request, id: id, once: hasLeft) }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            leave(request, id: id, once: hasLeft)
        }
    }

    /// Starts low-priority loads nobody is waiting for yet. They run to
    /// completion, whoever joins and leaves them meanwhile.
    func prefetch(_ requests: [ImageRequest]) {
        entries.withLock { entries in
            for request in requests {
                var entry = start(request, priority: .utility, in: &entries)
                entry.isPinned = true
                entries[request] = entry
            }
        }
    }

    /// Number of loads currently in flight. For tests.
    var count: Int { entries.withLock { $0.count } }

    /// The entry for `request`, starting its load if none is in flight.
    /// Called with the lock held.
    private func start(_ request: ImageRequest, priority: TaskPriority, in entries: inout [ImageRequest: Entry]) -> Entry {
        if let entry = entries[request] { return entry }
        let id = UUID()
        let task = Task(priority: priority) {
            defer { self.forget(request, id: id) }
            return try await load(request)
        }
        return Entry(id: id, task: task)
    }

    /// One caller stops waiting, whether it finished or was cancelled; the
    /// `once` flag makes sure each caller counts once.
    private func leave(_ request: ImageRequest, id: UUID, once hasLeft: OSAllocatedUnfairLock<Bool>) {
        let isFirstLeave = hasLeft.withLock { hasLeft in
            defer { hasLeft = true }
            return !hasLeft
        }
        guard isFirstLeave else { return }
        entries.withLock { entries in
            guard var entry = entries[request], entry.id == id else { return }
            entry.waiters -= 1
            entries[request] = entry
        }
        Task { [grace] in
            try? await Task.sleep(for: grace)
            cancelIfAbandoned(request, id: id)
        }
    }

    /// Cancels the load if nobody has joined it since its last caller left.
    private func cancelIfAbandoned(_ request: ImageRequest, id: UUID) {
        entries.withLock { entries in
            guard let entry = entries[request], entry.id == id,
                  entry.waiters == 0, !entry.isPinned else { return }
            entry.task.cancel()
            // A new request for the same image starts afresh.
            entries[request] = nil
        }
    }

    private func forget(_ request: ImageRequest, id: UUID) {
        entries.withLock { entries in
            if entries[request]?.id == id { entries[request] = nil }
        }
    }
}
