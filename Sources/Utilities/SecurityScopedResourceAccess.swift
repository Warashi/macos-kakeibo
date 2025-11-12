import Foundation

/// ユーザーが選択したセキュリティスコープ付きURLへのアクセスを管理する
internal enum SecurityScopedResourceAccess {
    @MainActor
    @discardableResult
    internal static func perform<T>(
        with url: URL,
        controller: SecurityScopedResourceAccessControlling = SystemResourceAccessController(),
        _ work: () throws -> T,
    ) rethrows -> T {
        let isAccessing = controller.startAccessing(url)
        defer {
            if isAccessing {
                controller.stopAccessing(url)
            }
        }
        return try work()
    }

    @MainActor
    @discardableResult
    internal static func performAsync<T>(
        with url: URL,
        controller: SecurityScopedResourceAccessControlling = SystemResourceAccessController(),
        _ work: () async throws -> T,
    ) async rethrows -> T {
        let isAccessing = controller.startAccessing(url)
        defer {
            if isAccessing {
                controller.stopAccessing(url)
            }
        }
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
