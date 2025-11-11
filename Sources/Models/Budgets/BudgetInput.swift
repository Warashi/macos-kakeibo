import Foundation

/// 月次予算の入力パラメータ
internal struct BudgetInput {
    internal let amount: Decimal
    internal let categoryId: UUID?
    internal let startYear: Int
    internal let startMonth: Int
    internal let endYear: Int
    internal let endMonth: Int
}

/// 年次特別枠の割当ドラフト
internal struct AnnualAllocationDraft {
    internal let categoryId: UUID
    internal let amount: Decimal
    internal let policyOverride: AnnualBudgetPolicy?

    internal init(
        categoryId: UUID,
        amount: Decimal,
        policyOverride: AnnualBudgetPolicy? = nil
    ) {
        self.categoryId = categoryId
        self.amount = amount
        self.policyOverride = policyOverride
    }
}
