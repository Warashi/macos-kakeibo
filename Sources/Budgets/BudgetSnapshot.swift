import Foundation

internal struct BudgetSnapshot: Sendable {
    internal let budgets: [BudgetDTO]
    internal let transactions: [TransactionDTO]
    internal let categories: [CategoryDTO]
    internal let annualBudgetConfig: AnnualBudgetConfigDTO?
    internal let specialPaymentDefinitions: [SpecialPaymentDefinitionDTO]
    internal let specialPaymentBalances: [SpecialPaymentSavingBalanceDTO]
    internal let specialPaymentOccurrences: [SpecialPaymentOccurrenceDTO]
}
