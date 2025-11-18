import Foundation
import SwiftData

/// 設定/インポート機能で共有する依存関係
internal struct SettingsStackDependencies: Sendable {
    internal let transactionRepository: TransactionRepository
    internal let budgetRepository: BudgetRepository
}

/// 設定・CSVインポート周りのストア構築ビルダー
///
/// Repository の生成を 1 か所に集約することで、
/// 将来的に `@ModelActor` 化した際の変更範囲を限定する。
internal enum SettingsStackBuilder {
    /// 依存関係を構築
    internal static func makeDependencies(modelContainer: ModelContainer) async -> SettingsStackDependencies {
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: modelContainer)
        let budgetRepository = SwiftDataBudgetRepository(modelContainer: modelContainer)
        return SettingsStackDependencies(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )
    }

    /// SettingsStore を構築
    @MainActor
    internal static func makeSettingsStore(modelContainer: ModelContainer) async -> SettingsStore {
        let dependencies = await makeDependencies(modelContainer: modelContainer)
        return await SettingsStore(
            modelContainer: modelContainer,
            transactionRepository: dependencies.transactionRepository,
            budgetRepository: dependencies.budgetRepository,
        )
    }

    /// ImportStore を構築
    @MainActor
    internal static func makeImportStore(modelContainer: ModelContainer) async -> ImportStore {
        let dependencies = await makeDependencies(modelContainer: modelContainer)
        return ImportStore(
            transactionRepository: dependencies.transactionRepository,
            budgetRepository: dependencies.budgetRepository,
        )
    }
}
