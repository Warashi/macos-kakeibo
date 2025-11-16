import Foundation

/// Dashboardに必要なデータセット
internal struct DashboardSnapshot: Sendable {
    internal let monthlyTransactions: [TransactionDTO]
    internal let annualTransactions: [TransactionDTO]
    internal let budgets: [BudgetDTO]
    internal let categories: [CategoryDTO]
    internal let config: AnnualBudgetConfigDTO?
}
