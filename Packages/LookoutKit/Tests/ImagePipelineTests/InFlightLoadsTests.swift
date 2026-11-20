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

    @Test func cancelledCallerDoesNotStopTheLoad() async throws {
        let gate = Gate()
        let finished = Counter()
        let loads = InFlightLoads { _ in
            await gate.wait()
            await finished.increment()
            return UIImage()
        }

        let leaving = Task { try await loads.image(for: request) }
        await waitUntil { loads.count == 1 }
        leaving.cancel()
        await gate.open()

        await waitUntil { await finished.value == 1 }
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
