import Foundation

/// Dashboardに必要なデータセット
internal struct DashboardSnapshot: Sendable {
    internal let monthlyTransactions: [Transaction]
    internal let annualTransactions: [Transaction]
    internal let budgets: [BudgetDTO]
    internal let categories: [Category]
    internal let config: AnnualBudgetConfigDTO?
}
