import Foundation

// MARK: - 年次特別枠計算結果型

/// 年次特別枠の使用状況
internal struct AnnualBudgetUsage: Sendable {
    /// 対象年
    internal let year: Int

    /// 年次特別枠総額
    internal let totalAmount: Decimal

    /// 使用済み金額
    internal let usedAmount: Decimal

    /// 残額
    internal let remainingAmount: Decimal

    /// 使用率（0.0 〜 1.0）
    internal let usageRate: Double

    /// カテゴリ別累積充当結果
    internal let categoryAllocations: [CategoryAllocation]
}

/// カテゴリ別年次特別枠充当結果
internal struct CategoryAllocation: Sendable, Identifiable {
    /// カテゴリID
    internal let categoryId: UUID

    /// カテゴリ名
    internal let categoryName: String

    /// 年次特別枠の設定額
    internal let annualBudgetAmount: Decimal

    /// 月次予算額
    internal let monthlyBudgetAmount: Decimal

    /// 実績額（支出）
    internal let actualAmount: Decimal

    /// 予算超過額（全額年次枠扱いのカテゴリでは実績額）
    internal let excessAmount: Decimal

    /// 年次特別枠から充当可能な金額
    internal let allocatableAmount: Decimal

    /// 充当後の残額
    internal let remainingAfterAllocation: Decimal

    /// IdentifiableプロトコルのためのIDプロパティ
    internal var id: UUID {
        categoryId
    }

    /// 年次特別枠の残額（マイナス値は超過）
    internal var annualBudgetRemainingAmount: Decimal {
        annualBudgetAmount - allocatableAmount
    }

    /// 年次特別枠の使用率
    internal var annualBudgetUsageRate: Double {
        guard annualBudgetAmount > 0 else { return 0 }
        return NSDecimalNumber(decimal: allocatableAmount)
            .doubleValue / NSDecimalNumber(decimal: annualBudgetAmount).doubleValue
    }
}

/// 月次の年次特別枠充当結果
internal struct MonthlyAllocation: Sendable {
    /// 対象年
    internal let year: Int

    /// 対象月
    internal let month: Int

    /// 年次特別枠使用状況
    internal let annualBudgetUsage: AnnualBudgetUsage

    /// カテゴリ別充当結果
    internal let categoryAllocations: [CategoryAllocation]
}

// MARK: - 計算パラメータ

/// 年次特別枠計算パラメータ
internal struct AllocationCalculationParams {
    /// 取引リスト
    internal let transactions: [Transaction]

    /// 予算リスト
    internal let budgets: [Budget]

    /// 年次特別枠設定
    internal let annualBudgetConfig: AnnualBudgetConfig

    /// 集計フィルタ
    internal let filter: AggregationFilter

    internal init(
        transactions: [Transaction],
        budgets: [Budget],
        annualBudgetConfig: AnnualBudgetConfig,
        filter: AggregationFilter = .default,
    ) {
        self.transactions = transactions
        self.budgets = budgets
        self.annualBudgetConfig = annualBudgetConfig
        self.filter = filter
    }
}
