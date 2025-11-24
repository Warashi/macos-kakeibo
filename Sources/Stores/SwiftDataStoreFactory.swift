import Foundation
import SwiftData

/// SwiftDataを使用したStoreFactory実装
///
/// ModelContainerを保持し、各StackBuilderを使ってStoreを作成します。
internal final class SwiftDataStoreFactory: StoreFactory, @unchecked Sendable {
    private let modelContainer: ModelContainer

    internal init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    internal func makeBudgetStore() async -> BudgetStore {
        await BudgetStackBuilder.makeStore(modelContainer: modelContainer)
    }

    internal func makeTransactionStore() async -> TransactionStore {
        await TransactionStackBuilder.makeStore(modelContainer: modelContainer)
    }

    internal func makeDashboardStore() async -> DashboardStore {
        await DashboardStackBuilder.makeStore(modelContainer: modelContainer)
    }

    internal func makeSavingsGoalStore() async -> SavingsGoalStore {
        let repository = SwiftDataSavingsGoalRepository(modelContainer: modelContainer)
        let balanceRepository = SwiftDataSavingsGoalBalanceRepository(modelContainer: modelContainer)
        let withdrawalRepository = SwiftDataSavingsGoalWithdrawalRepository(modelContainer: modelContainer)

        return await SavingsGoalStore(
            repository: repository,
            balanceRepository: balanceRepository,
            withdrawalRepository: withdrawalRepository,
        )
    }

    internal func makeRecurringPaymentStore() async -> RecurringPaymentStore {
        await RecurringPaymentStackBuilder.makeStore(modelContainer: modelContainer)
    }

    internal func makeRecurringPaymentReconciliationStore() async -> RecurringPaymentReconciliationStore {
        await RecurringPaymentStackBuilder.makeReconciliationStore(modelContainer: modelContainer)
    }

    internal func makeRecurringPaymentListStore() async -> RecurringPaymentListStore {
        await RecurringPaymentStackBuilder.makeListStore(modelContainer: modelContainer)
    }

    internal func makeSettingsStore() async -> SettingsStore {
        await SettingsStackBuilder.makeSettingsStore(modelContainer: modelContainer)
    }

    internal func makeImportStore() async -> ImportStore {
        await SettingsStackBuilder.makeImportStore(modelContainer: modelContainer)
    }
}
