@testable import Kakeibo
import XCTest

final class SecurityScopedResourceAccessTests: XCTestCase {
    func testPerformExecutesWorkAndStopsAccessWhenStarted() throws {
        let url = URL(fileURLWithPath: "/tmp/test.csv")
        let controller = MockSecurityScopedResourceAccessController(startResult: true)

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

    func testPerformDoesNotStopWhenStartFails() throws {
        let url = URL(fileURLWithPath: "/tmp/another.csv")
        let controller = MockSecurityScopedResourceAccessController(startResult: false)

        _ = try SecurityScopedResourceAccess.perform(with: url, controller: controller) { 1 }

        XCTAssertEqual(controller.startCalls, [url])
        XCTAssertTrue(controller.stopCalls.isEmpty)
    }

    func testPerformAsyncStopsAccessAfterAwaitingWork() async throws {
        let url = URL(fileURLWithPath: "/tmp/async.csv")
        let controller = MockSecurityScopedResourceAccessController(startResult: true)

        let value = try await SecurityScopedResourceAccess.performAsync(with: url, controller: controller) {
            try await Task.sleep(nanoseconds: 1_000_000)
            return 42
        }

        XCTAssertEqual(value, 42)
        XCTAssertEqual(controller.startCalls, [url])
        XCTAssertEqual(controller.stopCalls, [url])
    }
}

private final class MockSecurityScopedResourceAccessController: SecurityScopedResourceAccessControlling {
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
