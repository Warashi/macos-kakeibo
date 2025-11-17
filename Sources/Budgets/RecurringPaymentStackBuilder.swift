import Foundation
import SwiftData

/// 定期支払い一覧ストア用の依存関係
internal struct RecurringPaymentListDependencies {
    internal let repository: RecurringPaymentRepository
}

/// 定期支払い突合ストア用の依存関係
internal struct RecurringPaymentReconciliationDependencies {
    internal let repository: RecurringPaymentRepository
    internal let transactionRepository: TransactionRepository
    internal let occurrencesService: RecurringPaymentOccurrencesService
}

/// 定期支払いスタック構築用のビルダー
///
/// Repository / Service の初期化を 1 か所へ集約し、
/// 将来的に `@ModelActor` 化する際の差分を最小限に抑える。
internal enum RecurringPaymentStackBuilder {
    /// 定期支払い一覧ストアの依存を構築
    /// - Parameter modelContainer: SwiftData ModelContainer
    internal static func makeListDependencies(modelContainer: ModelContainer) async -> RecurringPaymentListDependencies {
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: modelContainer)
        return RecurringPaymentListDependencies(repository: repository)
    }

    /// 定期支払い一覧ストアを構築
    internal static func makeListStore(modelContainer: ModelContainer) async -> RecurringPaymentListStore {
        let dependencies = await makeListDependencies(modelContainer: modelContainer)
        return await MainActor.run {
            RecurringPaymentListStore(repository: dependencies.repository)
        }
    }

    /// 突合ストアの依存を構築
    internal static func makeReconciliationDependencies(
        modelContainer: ModelContainer
    ) async -> RecurringPaymentReconciliationDependencies {
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: modelContainer)
        let transactionRepository = await SwiftDataTransactionRepository(modelContainer: modelContainer)
        let occurrencesService = await DefaultRecurringPaymentOccurrencesService(repository: repository)
        return RecurringPaymentReconciliationDependencies(
            repository: repository,
            transactionRepository: transactionRepository,
            occurrencesService: occurrencesService
        )
    }

    /// 定期支払い突合ストアを構築
    internal static func makeReconciliationStore(
        modelContainer: ModelContainer
    ) async -> RecurringPaymentReconciliationStore {
        let dependencies = await makeReconciliationDependencies(modelContainer: modelContainer)
        return await MainActor.run {
            RecurringPaymentReconciliationStore(
                repository: dependencies.repository,
                transactionRepository: dependencies.transactionRepository,
                occurrencesService: dependencies.occurrencesService
            )
        }
    }
}
