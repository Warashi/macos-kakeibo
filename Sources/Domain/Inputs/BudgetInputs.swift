import Foundation

/// 月次予算の入力パラメータ
internal struct BudgetInput: Sendable {
    internal let amount: Decimal
    internal let categoryId: UUID?
    internal let startYear: Int
    internal let startMonth: Int
    internal let endYear: Int
    internal let endMonth: Int
}

/// 月次予算の更新パラメータ
internal struct BudgetUpdateInput: Sendable {
    internal let id: UUID
    internal let input: BudgetInput
}

internal struct AnnualBudgetConfigInput: Sendable {
    internal let year: Int
    internal let totalAmount: Decimal
    internal let policy: AnnualBudgetPolicy
    internal let allocations: [AnnualAllocationDraft]
}

/// 年次特別枠の割当ドラフト
internal struct AnnualAllocationDraft: Sendable {
    internal let categoryId: UUID
    internal let amount: Decimal
    internal let policyOverride: AnnualBudgetPolicy?

    internal init(
        categoryId: UUID,
        amount: Decimal,
        policyOverride: AnnualBudgetPolicy? = nil,
    ) {
        self.categoryId = categoryId
        self.amount = amount
        self.policyOverride = policyOverride
    }
}
