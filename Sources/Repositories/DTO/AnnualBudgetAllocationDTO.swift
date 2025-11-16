import Foundation

/// 年次特別枠配分のDTO（Sendable）
internal struct AnnualBudgetAllocationDTO: Sendable, Hashable, Equatable {
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

    internal init(from allocation: AnnualBudgetAllocationEntity) {
        self.id = allocation.id
        self.amount = allocation.amount
        self.categoryId = allocation.category.id
        self.policyOverride = allocation.policyOverride
        self.configId = allocation.config?.id
        self.createdAt = allocation.createdAt
        self.updatedAt = allocation.updatedAt
    }
}
