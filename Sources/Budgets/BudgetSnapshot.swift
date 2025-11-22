import Foundation

internal struct BudgetSnapshot: Sendable {
    internal let budgets: [Budget]
    internal let transactions: [Transaction]
    internal let categories: [Category]
    internal let annualBudgetConfig: AnnualBudgetConfig?
    internal let recurringPaymentDefinitions: [RecurringPaymentDefinition]
    internal let recurringPaymentBalances: [RecurringPaymentSavingBalance]
    internal let recurringPaymentOccurrences: [RecurringPaymentOccurrence]
    internal let savingsGoals: [SavingsGoal]
    internal let savingsGoalBalances: [SavingsGoalBalance]
}
