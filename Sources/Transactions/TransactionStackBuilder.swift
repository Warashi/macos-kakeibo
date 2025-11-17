import Foundation
import SwiftData

/// 取引スタックの依存関係
internal struct TransactionStackDependencies: Sendable {
    internal let repository: TransactionRepository
    internal let listUseCase: TransactionListUseCaseProtocol
    internal let formUseCase: TransactionFormUseCaseProtocol
}

/// TransactionStore 準備用のビルダー
///
/// Repository / UseCase の生成を 1 か所へ集約することで、
/// 将来 `@ModelActor` 化する際の差分を最小限に抑える。
internal enum TransactionStackBuilder {
    /// 取引スタックの依存関係を構築
    /// - Parameter modelContainer: SwiftData ModelContainer
    /// - Returns: Repository / UseCase のセット
    internal static func makeDependencies(modelContainer: ModelContainer) async -> TransactionStackDependencies {
        let repository = await SwiftDataTransactionRepository(modelContainer: modelContainer)
        let listUseCase = await DefaultTransactionListUseCase(repository: repository)
        let formUseCase = await DefaultTransactionFormUseCase(repository: repository)
        return TransactionStackDependencies(
            repository: repository,
            listUseCase: listUseCase,
            formUseCase: formUseCase
        )
    }

    /// TransactionStore を構築
    /// - Parameter modelContainer: SwiftData ModelContainer
    /// - Returns: 初期化済みの TransactionStore
    internal static func makeStore(modelContainer: ModelContainer) async -> TransactionStore {
        let dependencies = await makeDependencies(modelContainer: modelContainer)
        return await MainActor.run {
            TransactionStore(
                listUseCase: dependencies.listUseCase,
                formUseCase: dependencies.formUseCase
            )
        }
    }
}
