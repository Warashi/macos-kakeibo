import Foundation

/// Store作成のためのFactory protocol
///
/// View層がSwiftDataに直接依存せずにStoreを取得できるようにします。
internal protocol StoreFactory: Sendable {
    /// BudgetStoreを作成
    func makeBudgetStore() async -> BudgetStore

    /// TransactionStoreを作成
    func makeTransactionStore() async -> TransactionStore

    /// DashboardStoreを作成
    func makeDashboardStore() async -> DashboardStore

    /// SavingsGoalStoreを作成
    func makeSavingsGoalStore() async -> SavingsGoalStore

    /// RecurringPaymentStoreを作成
    func makeRecurringPaymentStore() async -> RecurringPaymentStore

    /// RecurringPaymentReconciliationStoreを作成
    func makeRecurringPaymentReconciliationStore() async -> RecurringPaymentReconciliationStore

    /// RecurringPaymentListStoreを作成
    func makeRecurringPaymentListStore() async -> RecurringPaymentListStore

    /// RecurringPaymentSuggestionStoreを作成
    func makeRecurringPaymentSuggestionStore() async -> RecurringPaymentSuggestionStore

    /// SettingsStoreを作成
    func makeSettingsStore() async -> SettingsStore

    /// ImportStoreを作成
    func makeImportStore() async -> ImportStore
}
