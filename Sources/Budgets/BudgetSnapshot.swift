import Foundation

internal struct BudgetSnapshot: Sendable {
    internal let budgets: [Budget]
    internal let transactions: [Transaction]
    internal let categories: [Category]
    internal let annualBudgetConfig: AnnualBudgetConfig?
    internal let recurringPaymentDefinitions: [RecurringPaymentDefinitionDTO]
    internal let recurringPaymentBalances: [RecurringPaymentSavingBalanceDTO]
    internal let recurringPaymentOccurrences: [RecurringPaymentOccurrenceDTO]
}
