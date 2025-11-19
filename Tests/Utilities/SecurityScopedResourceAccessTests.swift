@testable import Kakeibo
import os.lock
import XCTest

internal final class SecurityScopedResourceAccessTests: XCTestCase {
    internal func testPerformExecutesWorkAndStopsAccessWhenStarted() throws {
        let url = URL(fileURLWithPath: "/tmp/test.csv")
        let controller = MockResourceAccessController(startResult: true)

        var executed = false
        let result = try SecurityScopedResourceAccess.perform(with: url, controller: controller) { () -> String in
            executed = true
            return "done"
        }

        XCTAssertTrue(executed)
        XCTAssertEqual(result, "done")
        XCTAssertEqual(controller.startCalls, [url])
        XCTAssertEqual(controller.stopCalls, [url])
    }

    internal func testPerformDoesNotStopWhenStartFails() throws {
        let url = URL(fileURLWithPath: "/tmp/another.csv")
        let controller = MockResourceAccessController(startResult: false)

        _ = try SecurityScopedResourceAccess.perform(with: url, controller: controller) { 1 }

        XCTAssertEqual(controller.startCalls, [url])
        XCTAssertTrue(controller.stopCalls.isEmpty)
    }

    internal func testPerformAsyncStopsAccessAfterAwaitingWork() async throws {
        let url = URL(fileURLWithPath: "/tmp/async.csv")
        let controller = MockResourceAccessController(startResult: true)

        let value = try await SecurityScopedResourceAccess.performAsync(with: url, controller: controller) {
            try await Task.sleep(nanoseconds: 1_000_000)
            return 42
        }

        XCTAssertEqual(value, 42)
        XCTAssertEqual(controller.startCalls, [url])
        XCTAssertEqual(controller.stopCalls, [url])
    }

    internal func testPerformStopsAccessEvenWhenWorkThrows() {
        enum SampleError: Error {
            case failure
        }
        let url = URL(fileURLWithPath: "/tmp/failure.csv")
        let controller = MockResourceAccessController(startResult: true)

        XCTAssertThrowsError(
            try SecurityScopedResourceAccess.perform(with: url, controller: controller) {
                throw SampleError.failure
            },
            "perform should propagate the thrown error",
        ) { error in
            XCTAssertTrue(error is SampleError)
        }

        XCTAssertEqual(controller.startCalls, [url])
        XCTAssertEqual(controller.stopCalls, [url])
    }

    internal func testPerformAsyncCanRunOffMainActor() async throws {
        let url = URL(fileURLWithPath: "/tmp/detached.csv")
        let controller = MockResourceAccessController(startResult: true)

        let (isMainThread, value) = try await Task.detached(priority: .userInitiated) {
            try await SecurityScopedResourceAccess.performAsync(with: url, controller: controller) {
                (Thread.isMainThread, 7)
            }
        }.value

        XCTAssertFalse(isMainThread, "work closure should not require MainActor")
        XCTAssertEqual(value, 7)
        XCTAssertEqual(controller.startCalls, [url])
        XCTAssertEqual(controller.stopCalls, [url])
    }
}

private final class MockResourceAccessController: SecurityScopedResourceAccessControlling, Sendable {
    private let startResult: Bool
    private let lock: OSAllocatedUnfairLock<ResourceAccessControllerState> = OSAllocatedUnfairLock(
        initialState: ResourceAccessControllerState(),
    )

    init(startResult: Bool) {
        self.startResult = startResult
    }

    var startCalls: [URL] {
        lock.withLock { $0.startCalls }
    }

    var stopCalls: [URL] {
        lock.withLock { $0.stopCalls }
    }

    func startAccessing(_ url: URL) -> Bool {
        lock.withLock { state in
            state.startCalls.append(url)
        }
        return startResult
    }

    func stopAccessing(_ url: URL) {
        lock.withLock { state in
            state.stopCalls.append(url)
        }
    }
}

private struct ResourceAccessControllerState {
    var startCalls: [URL] = []
    var stopCalls: [URL] = []
}
