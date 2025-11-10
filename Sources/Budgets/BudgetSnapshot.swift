import Foundation

internal struct BudgetSnapshot {
    internal let budgets: [Budget]
    internal let transactions: [Transaction]
    internal let categories: [Category]
    internal let annualBudgetConfig: AnnualBudgetConfig?
    internal let specialPaymentDefinitions: [SpecialPaymentDefinition]
    internal let specialPaymentBalances: [SpecialPaymentSavingBalance]
}
