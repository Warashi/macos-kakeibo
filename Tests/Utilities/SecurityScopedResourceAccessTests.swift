@testable import Kakeibo
import XCTest

@MainActor
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
}

private final class MockResourceAccessController: SecurityScopedResourceAccessControlling {
    private let startResult: Bool
    private(set) var startCalls: [URL] = []
    private(set) var stopCalls: [URL] = []

    init(startResult: Bool) {
        self.startResult = startResult
    }

    func startAccessing(_ url: URL) -> Bool {
        startCalls.append(url)
        return startResult
    }

    func stopAccessing(_ url: URL) {
        stopCalls.append(url)
    }
}
