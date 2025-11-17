import Foundation
import SwiftData

/// アクセススケジューラ：同時読取と直列書込のポリシー実装
///
/// SwiftDataのModelContextへの安全なアクセスを管理します。
/// - 書込操作: 直列実行（Overwrite問題を防ぐ）
/// - 読取操作: 並列実行（パフォーマンス向上）
///
/// 参考: iOSDC 2024 "Concurrency Safe SwiftData" by @himeshi_tech
/// https://gist.github.com/teamhimeh/912d4191e4f9fbcb33290e3b566c6635
public actor AccessScheduler {
    /// 操作タイプ
    private enum OperationType {
        case read
        case write
    }

    /// 操作
    private struct Operation {
        internal let id: UUID
        internal let continuation: CheckedContinuation<Void, Never>
        internal let type: OperationType
    }

    /// ModelContainer
    internal let container: ModelContainer

    /// 実行中の操作
    private var executingOperations: [Operation] = []

    /// 待機中の操作
    private var pendingOperations: [Operation] = []

    /// イニシャライザ
    /// - Parameter container: ModelContainer
    public init(container: ModelContainer) {
        self.container = container
    }

    /// 書込トランザクションを直列実行
    ///
    /// すべての書込操作は順番に実行され、同時に複数の書込が発生することはありません。
    /// これによりOverwrite問題を防ぎます。
    ///
    /// - Parameter block: 書込処理（ModelContextを受け取る）
    /// - Returns: 処理結果
    @discardableResult
    public func executeWrite<T>(block: @Sendable (ModelContext) throws -> T) async rethrows -> T where T: Sendable {
        try await _execute(type: .write) {
            try block(ModelContext(self.container))
        }
    }

    /// 読取トランザクションを並列実行
    ///
    /// 複数の読取操作が同時に実行されることで、パフォーマンスが向上します。
    /// 書込操作が実行中の場合は、書込完了まで待機します。
    ///
    /// - Parameter block: 読取処理（ModelContextを受け取る）
    /// - Returns: 処理結果
    public func executeRead<T>(
        block: @escaping @Sendable (ModelContext) throws -> T
    ) async rethrows -> T where T: Sendable {
        try await _execute(type: .read) {
            try await Task.detached {
                try block(ModelContext(self.container))
            }.value
        }
    }

    /// 操作を実行
    ///
    /// - Parameters:
    ///   - type: 操作タイプ（read/write）
    ///   - block: 実行する処理
    /// - Returns: 処理結果
    private func _execute<T>(
        type: OperationType,
        block: () async throws -> T,
    ) async rethrows -> T where T: Sendable {
        let id = UUID()
        await withCheckedContinuation {
            pendingOperations.append(Operation(id: id, continuation: $0, type: type))
            popPendingOperations()
        }
        let result = try await block()
        executingOperations.removeAll { $0.id == id }
        popPendingOperations()
        return result
    }

    /// 待機中の操作をキューから取り出して実行開始
    ///
    /// - 実行中の操作がない場合のみ、新しい操作を開始
    /// - 読取操作は複数同時実行可能
    /// - 書込操作は1つのみ実行（直列化）
    private func popPendingOperations() {
        guard executingOperations.isEmpty else { return }
        while !pendingOperations.isEmpty {
            let pendingOperation = pendingOperations.removeFirst()
            executingOperations.append(pendingOperation)
            pendingOperation.continuation.resume()
            guard pendingOperation.type == .read else {
                // Allow only one execution
                break
            }
        }
    }
}

extension AccessScheduler: DatabaseScheduling {}
