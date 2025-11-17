import Foundation
import SwiftData

/// SwiftData の ModelContainer から短命 ModelContext を供給するヘルパー
internal final class DatabaseAccess: Sendable {
    private let scheduler: AccessScheduler

    internal init(container: ModelContainer) {
        self.scheduler = AccessScheduler(container: container)
    }

    /// 読み取り処理を並列実行
    internal func read<T: Sendable>(
        _ block: @escaping @Sendable (ModelContext) throws -> T,
    ) async throws -> T {
        try await scheduler.executeRead { context in
            Result { try block(context) }
        }.get()
    }

    /// 書き込み処理を直列実行
    @discardableResult
    internal func write<T: Sendable>(
        _ block: @escaping @Sendable (ModelContext) throws -> T,
    ) async throws -> T {
        try await scheduler.executeWrite { context in
            try block(context)
        }
    }

    /// 任意の用途向けに新しい ModelContext を生成
    internal func makeContext() -> ModelContext {
        ModelContext(scheduler.container)
    }
}

internal extension ModelContainer {
    /// DatabaseAccess を生成
    func makeDatabaseAccess() -> DatabaseAccess {
        DatabaseAccess(container: self)
    }

    /// テスト向けヘルパー：インメモリ構成の DatabaseAccess
    static func makeInMemoryAccess() throws -> DatabaseAccess {
        try DatabaseAccess(container: createInMemoryContainer())
    }
}
