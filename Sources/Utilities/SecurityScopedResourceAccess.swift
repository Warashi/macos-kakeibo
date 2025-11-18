import Foundation
import OSLog

/// ユーザーが選択したセキュリティスコープ付きURLへのアクセスを管理する
internal enum SecurityScopedResourceAccess {
    private static let logger = Logger(
        subsystem: "com.warashi.macos-kakeibo",
        category: "SecurityScopedResourceAccess",
    )

    /// セキュリティスコープ付きURLでワーククロージャを実行する。
    /// - Note: UI更新など MainActor が必要な処理は呼び出し側で `await MainActor.run` を使ってください。
    @discardableResult
    internal static func perform<T>(
        with url: URL,
        controller: SecurityScopedResourceAccessControlling = SystemResourceAccessController(),
        _ work: @Sendable () throws -> T,
    ) rethrows -> T {
        let session = SecurityScopedAccessSession(
            url: url,
            controller: controller,
            logger: logger,
        )
        defer { session.finish() }
        return try work()
    }

    /// 非同期ワーク版。MainActor は呼び出し元で制御する。
    @discardableResult
    internal static func performAsync<T>(
        with url: URL,
        controller: SecurityScopedResourceAccessControlling = SystemResourceAccessController(),
        _ work: @Sendable () async throws -> T,
    ) async rethrows -> T {
        let session = SecurityScopedAccessSession(
            url: url,
            controller: controller,
            logger: logger,
        )
        defer { session.finish() }
        return try await work()
    }
}

internal protocol SecurityScopedResourceAccessControlling {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

internal struct SystemResourceAccessController: SecurityScopedResourceAccessControlling {
    internal func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    internal func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

private final class SecurityScopedAccessSession {
    private let url: URL
    private let controller: SecurityScopedResourceAccessControlling
    private let logger: Logger
    private let didStart: Bool
    private var didStop: Bool = false

    init(
        url: URL,
        controller: SecurityScopedResourceAccessControlling,
        logger: Logger,
    ) {
        self.url = url
        self.controller = controller
        self.logger = logger
        didStart = controller.startAccessing(url)
        if didStart {
            logger.debug("Started security scoped access for \(self.url, privacy: .public)")
        } else {
            logger.warning("Failed to start security scoped access for \(self.url, privacy: .public)")
        }
    }

    func finish() {
        guard didStart else { return }
        controller.stopAccessing(url)
        didStop = true
        logger.debug("Stopped security scoped access for \(self.url, privacy: .public)")
    }

    deinit {
        if didStart, !didStop {
            assertionFailure("SecurityScopedAccessSession for \(self.url) ended without stopping access.")
        }
    }
}
