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
        let repository = SwiftDataTransactionRepository(modelContainer: modelContainer)
        let listUseCase = DefaultTransactionListUseCase(repository: repository)
        let formUseCase = DefaultTransactionFormUseCase(repository: repository)
        return TransactionStackDependencies(
            repository: repository,
            listUseCase: listUseCase,
            formUseCase: formUseCase,
        )
    }

    /// TransactionStore を構築
    /// - Parameters:
    ///   - modelContainer: SwiftData ModelContainer
    ///   - appState: アプリケーション状態（画面間で共有される年月を管理）
    /// - Returns: 初期化済みの TransactionStore
    internal static func makeStore(modelContainer: ModelContainer, appState: AppState) async -> TransactionStore {
        let dependencies = await makeDependencies(modelContainer: modelContainer)
        return await MainActor.run {
            TransactionStore(
                listUseCase: dependencies.listUseCase,
                formUseCase: dependencies.formUseCase,
                appState: appState,
            )
        }
    }

    /// 取引スタックの依存関係を ModelActor から構築
    /// - Parameter modelActor: 取引用 ModelActor
    internal static func makeDependencies(modelActor: TransactionModelActor) async -> TransactionStackDependencies {
        let container = modelActor.modelContainer
        return await makeDependencies(modelContainer: container)
    }

    /// TransactionStore を ModelActor ベースで構築
    /// - Parameters:
    ///   - modelActor: 取引用 ModelActor
    ///   - appState: アプリケーション状態（画面間で共有される年月を管理）
    internal static func makeStore(modelActor: TransactionModelActor, appState: AppState) async -> TransactionStore {
        let dependencies = await makeDependencies(modelActor: modelActor)
        return await MainActor.run {
            TransactionStore(
                listUseCase: dependencies.listUseCase,
                formUseCase: dependencies.formUseCase,
                appState: appState,
            )
        }
    }
}
