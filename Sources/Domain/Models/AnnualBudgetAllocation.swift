import Foundation

/// ドメイン層で扱う年次特別枠カテゴリ配分
internal struct AnnualBudgetAllocation: Sendable, Hashable, Equatable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID
    internal let policyOverride: AnnualBudgetPolicy?
    internal let configId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        amount: Decimal,
        categoryId: UUID,
        policyOverride: AnnualBudgetPolicy?,
        configId: UUID?,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.policyOverride = policyOverride
        self.configId = configId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

}
