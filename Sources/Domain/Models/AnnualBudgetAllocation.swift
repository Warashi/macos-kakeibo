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
}
