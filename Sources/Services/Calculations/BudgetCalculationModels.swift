import Foundation

// MARK: - 予算計算結果型

/// 予算計算結果
internal struct BudgetCalculation: Sendable {
    /// 予算額
    internal let budgetAmount: Decimal

    /// 実績額（支出）
    internal let actualAmount: Decimal

    /// 残額（予算額 - 実績額）
    internal let remainingAmount: Decimal

    /// 使用率（0.0 〜 1.0）
    internal let usageRate: Double

    /// 予算超過フラグ
    internal let isOverBudget: Bool
}

/// カテゴリ別予算計算結果
internal struct CategoryBudgetCalculation: Sendable {
    /// カテゴリID
    internal let categoryId: UUID

    /// カテゴリ名
    internal let categoryName: String

    /// 予算計算結果
    internal let calculation: BudgetCalculation
}

/// 月次予算計算結果
internal struct MonthlyBudgetCalculation: Sendable {
    /// 対象年
    internal let year: Int

    /// 対象月
    internal let month: Int

    /// 全体予算計算
    internal let overallCalculation: BudgetCalculation?

    /// カテゴリ別予算計算
    internal let categoryCalculations: [CategoryBudgetCalculation]
}

// MARK: - 定期支払い積立計算結果型

/// 定期支払い積立計算パラメータ
internal struct RecurringPaymentSavingsCalculationInput: Sendable {
    /// 定期支払い定義リスト（DTO）
    internal let definitions: [RecurringPaymentDefinition]

    /// 積立残高リスト（DTO）
    internal let balances: [RecurringPaymentSavingBalance]

    /// 発生予定リスト（DTO）
    internal let occurrences: [RecurringPaymentOccurrence]

    /// 対象年
    internal let year: Int

    /// 対象月
    internal let month: Int
}

/// 定期支払い積立計算結果
internal struct RecurringPaymentSavingsCalculation: Sendable {
    /// 定義ID
    internal let definitionId: UUID

    /// 名称
    internal let name: String

    /// 月次積立金額
    internal let monthlySaving: Decimal

    /// 累計積立額
    internal let totalSaved: Decimal

    /// 累計支払額
    internal let totalPaid: Decimal

    /// 残高
    internal let balance: Decimal

    /// 次回発生予定日
    internal let nextOccurrence: Date?
}
