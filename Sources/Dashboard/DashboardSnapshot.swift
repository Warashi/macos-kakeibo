import Foundation

/// Dashboardに必要なデータセット
internal struct DashboardSnapshot: Sendable {
    internal let monthlyTransactions: [Transaction]
    internal let annualTransactions: [Transaction]
    internal let budgets: [Budget]
    internal let categories: [Category]
    internal let config: AnnualBudgetConfig?
    internal let savingsGoals: [SavingsGoal]
    internal let savingsGoalBalances: [SavingsGoalBalance]
}
