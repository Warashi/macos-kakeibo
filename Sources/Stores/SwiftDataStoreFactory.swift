import Foundation
import SwiftData

/// SwiftDataを使用したStoreFactory実装
///
/// ModelContainerを保持し、各StackBuilderを使ってStoreを作成します。
internal final class SwiftDataStoreFactory: StoreFactory, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let appState: AppState

    internal init(modelContainer: ModelContainer, appState: AppState) {
        self.modelContainer = modelContainer
        self.appState = appState
    }

    internal func makeBudgetStore() async -> BudgetStore {
        await BudgetStackBuilder.makeStore(modelContainer: modelContainer, appState: appState)
    }

    internal func makeTransactionStore() async -> TransactionStore {
        await TransactionStackBuilder.makeStore(modelContainer: modelContainer, appState: appState)
    }

    internal func makeDashboardStore() async -> DashboardStore {
        await DashboardStackBuilder.makeStore(modelContainer: modelContainer, appState: appState)
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

    internal func makeRecurringPaymentSuggestionStore() async -> RecurringPaymentSuggestionStore {
        await RecurringPaymentStackBuilder.makeSuggestionStore(modelContainer: modelContainer)
    }

    internal func makeSettingsStore() async -> SettingsStore {
        await SettingsStackBuilder.makeSettingsStore(modelContainer: modelContainer)
    }

    internal func makeImportStore() async -> ImportStore {
        await SettingsStackBuilder.makeImportStore(modelContainer: modelContainer)
    }
}
