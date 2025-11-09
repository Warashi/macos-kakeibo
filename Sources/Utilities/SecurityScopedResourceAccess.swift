import Foundation

/// ユーザーが選択したセキュリティスコープ付きURLへのアクセスを管理する
internal enum SecurityScopedResourceAccess {
    @MainActor @discardableResult
    static func perform<T>(
        with url: URL,
        controller: SecurityScopedResourceAccessControlling = SystemSecurityScopedResourceAccessController(),
        _ work: () throws -> T
    ) rethrows -> T {
        let isAccessing = controller.startAccessing(url)
        defer {
            if isAccessing {
                controller.stopAccessing(url)
            }
        }
        return try work()
    }

    @MainActor @discardableResult
    static func performAsync<T>(
        with url: URL,
        controller: SecurityScopedResourceAccessControlling = SystemSecurityScopedResourceAccessController(),
        _ work: () async throws -> T
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

internal struct SystemSecurityScopedResourceAccessController: SecurityScopedResourceAccessControlling {
    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
