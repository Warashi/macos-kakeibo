import Foundation
import SwiftData

/// 定期支払い一覧ストア用の依存関係
internal struct RecurringPaymentListDependencies {
    internal let repository: RecurringPaymentRepository
    internal let budgetRepository: BudgetRepository
}

/// 定期支払い突合ストア用の依存関係
internal struct RecurringPaymentReconciliationDeps {
    internal let repository: RecurringPaymentRepository
    internal let transactionRepository: TransactionRepository
    internal let occurrencesService: RecurringPaymentOccurrencesService
}

/// 定期支払い CRUD ストア用の依存関係
internal struct RecurringPaymentStoreDependencies {
    internal let repository: RecurringPaymentRepository
}

/// 定期支払いスタック構築用のビルダー
///
/// Repository / Service の初期化を 1 か所へ集約し、
/// 将来的に `@ModelActor` 化する際の差分を最小限に抑える。
internal enum RecurringPaymentStackBuilder {
    /// 定期支払い一覧ストアの依存を構築
    /// - Parameter modelContainer: SwiftData ModelContainer
    internal static func makeListDependencies(modelContainer: ModelContainer) async
    -> RecurringPaymentListDependencies {
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: modelContainer)
        let budgetRepository = SwiftDataBudgetRepository(modelContainer: modelContainer)
        return RecurringPaymentListDependencies(
            repository: repository,
            budgetRepository: budgetRepository
        )
    }

    /// 定期支払い一覧ストアを構築
    internal static func makeListStore(modelContainer: ModelContainer) async -> RecurringPaymentListStore {
        let dependencies = await makeListDependencies(modelContainer: modelContainer)
        return await MainActor.run {
            RecurringPaymentListStore(
                repository: dependencies.repository,
                budgetRepository: dependencies.budgetRepository
            )
        }
    }

    /// 突合ストアの依存を構築
    internal static func makeReconciliationDependencies(
        modelContainer: ModelContainer,
    ) async -> RecurringPaymentReconciliationDeps {
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: modelContainer)
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: modelContainer)
        let occurrencesService = RecurringPaymentOccurrencesServiceImpl(repository: repository)
        return RecurringPaymentReconciliationDeps(
            repository: repository,
            transactionRepository: transactionRepository,
            occurrencesService: occurrencesService,
        )
    }

    /// 定期支払い突合ストアを構築
    internal static func makeReconciliationStore(
        modelContainer: ModelContainer,
    ) async -> RecurringPaymentReconciliationStore {
        let dependencies = await makeReconciliationDependencies(modelContainer: modelContainer)
        return await MainActor.run {
            RecurringPaymentReconciliationStore(
                repository: dependencies.repository,
                transactionRepository: dependencies.transactionRepository,
                occurrencesService: dependencies.occurrencesService,
            )
        }
    }

    /// 定期支払い CRUD ストアの依存を構築
    internal static func makeStoreDependencies(modelContainer: ModelContainer) async
    -> RecurringPaymentStoreDependencies {
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: modelContainer)
        return RecurringPaymentStoreDependencies(repository: repository)
    }

    /// 定期支払い CRUD ストアを構築
    internal static func makeStore(modelContainer: ModelContainer) async -> RecurringPaymentStore {
        let dependencies = await makeStoreDependencies(modelContainer: modelContainer)
        return RecurringPaymentStore(repository: dependencies.repository)
    }

    /// 定期支払い一覧ストアの依存を ModelActor から構築
    internal static func makeListDependencies(modelActor: RecurringPaymentModelActor) async
    -> RecurringPaymentListDependencies {
        let container = modelActor.modelContainer
        return await makeListDependencies(modelContainer: container)
    }

    /// 定期支払い一覧ストアを ModelActor ベースで構築
    internal static func makeListStore(modelActor: RecurringPaymentModelActor) async -> RecurringPaymentListStore {
        let dependencies = await makeListDependencies(modelActor: modelActor)
        return await MainActor.run {
            RecurringPaymentListStore(
                repository: dependencies.repository,
                budgetRepository: dependencies.budgetRepository
            )
        }
    }

    /// 突合ストアの依存を ModelActor から構築
    internal static func makeReconciliationDependencies(modelActor: RecurringPaymentModelActor) async
    -> RecurringPaymentReconciliationDeps {
        let container = modelActor.modelContainer
        return await makeReconciliationDependencies(modelContainer: container)
    }

    /// 定期支払い突合ストアを ModelActor ベースで構築
    internal static func makeReconciliationStore(modelActor: RecurringPaymentModelActor) async
    -> RecurringPaymentReconciliationStore {
        let dependencies = await makeReconciliationDependencies(modelActor: modelActor)
        return await MainActor.run {
            RecurringPaymentReconciliationStore(
                repository: dependencies.repository,
                transactionRepository: dependencies.transactionRepository,
                occurrencesService: dependencies.occurrencesService,
            )
        }
    }

    /// 定期支払い CRUD ストアの依存を ModelActor から構築
    internal static func makeStoreDependencies(modelActor: RecurringPaymentModelActor) async
    -> RecurringPaymentStoreDependencies {
        let container = modelActor.modelContainer
        return await makeStoreDependencies(modelContainer: container)
    }

    /// 定期支払い CRUD ストアを ModelActor ベースで構築
    internal static func makeStore(modelActor: RecurringPaymentModelActor) async -> RecurringPaymentStore {
        let dependencies = await makeStoreDependencies(modelActor: modelActor)
        return RecurringPaymentStore(repository: dependencies.repository)
    }
}
