import Foundation

internal struct BudgetSnapshot: Sendable {
    internal let budgets: [BudgetDTO]
    internal let transactions: [TransactionDTO]
    internal let categories: [Category]
    internal let annualBudgetConfig: AnnualBudgetConfigDTO?
    internal let recurringPaymentDefinitions: [RecurringPaymentDefinitionDTO]
    internal let recurringPaymentBalances: [RecurringPaymentSavingBalanceDTO]
    internal let recurringPaymentOccurrences: [RecurringPaymentOccurrenceDTO]
}
