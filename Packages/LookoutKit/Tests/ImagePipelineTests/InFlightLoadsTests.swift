import Foundation
import ImageLoading
import Testing
import UIKit
@testable import ImagePipeline

struct InFlightLoadsTests {
    private let request = ImageRequest(url: URL(string: "https://example.com/a.jpg")!, maxPixelSize: 100)

    @Test func concurrentCallersShareOneLoad() async throws {
        let gate = Gate()
        let started = Counter()
        let loads = InFlightLoads { _ in
            await started.increment()
            await gate.wait()
            return UIImage()
        }

        async let first = loads.image(for: request)
        async let second = loads.image(for: request)
        await waitUntil { await started.value == 1 }
        await gate.open()
        let (a, b) = try await (first, second)

        #expect(a === b)
        #expect(await started.value == 1)
    }

    @Test func callerJoinsAPrefetchInFlight() async throws {
        let gate = Gate()
        let started = Counter()
        let loads = InFlightLoads { _ in
            await started.increment()
            await gate.wait()
            return UIImage()
        }

        loads.prefetch([request])
        async let image = loads.image(for: request)
        await gate.open()
        _ = try await image

        #expect(await started.value == 1)
    }

    @Test func finishedLoadsAreForgotten() async throws {
        let loads = InFlightLoads { _ in UIImage() }

        _ = try await loads.image(for: request)

        await waitUntil { loads.count == 0 }
    }

    /// A load that waits for `gate`, then counts whether it finished or
    /// noticed it was cancelled.
    private func gatedLoads(gate: Gate, finished: Counter, cancelled: Counter) -> InFlightLoads {
        InFlightLoads { _ in
            await gate.wait()
            if Task.isCancelled {
                await cancelled.increment()
                throw CancellationError()
            }
            await finished.increment()
            return UIImage()
        }
    }

    @Test func soleWaiterCancellingCancelsTheLoad() async throws {
        let (gate, finished, cancelled) = (Gate(), Counter(), Counter())
        let loads = gatedLoads(gate: gate, finished: finished, cancelled: cancelled)

        let leaving = Task { try await loads.image(for: request) }
        await waitUntil { loads.count == 1 }
        leaving.cancel()
        await waitUntil { loads.count == 0 }
        await gate.open()

        await waitUntil { await cancelled.value == 1 }
        #expect(await finished.value == 0)
    }

    @Test func sharedLoadSurvivesOneWaiterCancelling() async throws {
        let (gate, finished, cancelled) = (Gate(), Counter(), Counter())
        let loads = gatedLoads(gate: gate, finished: finished, cancelled: cancelled)

        let leaving = Task { try await loads.image(for: request) }
        let staying = Task { try await loads.image(for: request) }
        await waitUntil { loads.count == 1 }
        try await Task.sleep(for: .milliseconds(20)) // both callers have joined
        leaving.cancel()
        await gate.open()

        _ = try await staying.value
        #expect(await finished.value == 1)
        #expect(await cancelled.value == 0)
    }

    @Test func prefetchedLoadIsNeverCancelled() async throws {
        let (gate, finished, cancelled) = (Gate(), Counter(), Counter())
        let loads = gatedLoads(gate: gate, finished: finished, cancelled: cancelled)

        loads.prefetch([request])
        let joining = Task { try await loads.image(for: request) }
        try await Task.sleep(for: .milliseconds(20))
        joining.cancel()
        await gate.open()

        await waitUntil { await finished.value == 1 }
        #expect(await cancelled.value == 0)
    }

    @Test func requestAfterACancelledLoadStartsAfresh() async throws {
        let (gate, finished, cancelled) = (Gate(), Counter(), Counter())
        let loads = gatedLoads(gate: gate, finished: finished, cancelled: cancelled)

        let leaving = Task { try await loads.image(for: request) }
        await waitUntil { loads.count == 1 }
        leaving.cancel()
        await waitUntil { loads.count == 0 }
        let returning = Task { try await loads.image(for: request) }
        await gate.open()

        _ = try await returning.value
        #expect(await finished.value == 1)
    }
}

// MARK: - Helpers

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

/// Polls a condition, failing the test after 2 seconds instead of hanging.
private func waitUntil(_ condition: () async -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    let deadline = ContinuousClock.now + .seconds(2)
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Condition not met within 2 seconds", sourceLocation: sourceLocation)
}
