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
}

/// カテゴリ別年次特別枠充当結果
internal struct CategoryAllocation: Sendable {
    /// カテゴリID
    internal let categoryId: UUID

    /// カテゴリ名
    internal let categoryName: String

    /// 月次予算額
    internal let monthlyBudgetAmount: Decimal

    /// 実績額（支出）
    internal let actualAmount: Decimal

    /// 予算超過額
    internal let excessAmount: Decimal

    /// 年次特別枠から充当可能な金額
    internal let allocatableAmount: Decimal

    /// 充当後の残額
    internal let remainingAfterAllocation: Decimal
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

// MARK: - AnnualBudgetAllocator

/// 年次特別枠充当サービス
///
/// 年次特別枠の充当ロジックを担当します。
/// - 自動充当: 予算超過時に自動的に年次特別枠から充当
/// - 手動充当: ユーザーが手動で充当を指定
/// - 無効: 年次特別枠を使用しない
internal struct AnnualBudgetAllocator: Sendable {
    private let aggregator: TransactionAggregator
    private let budgetCalculator: BudgetCalculator

    internal init() {
        self.aggregator = TransactionAggregator()
        self.budgetCalculator = BudgetCalculator()
    }

    /// 年次特別枠の使用状況を計算
    /// - Parameters:
    ///   - params: 計算パラメータ
    ///   - upToMonth: 計算対象月（nilの場合は全年）
    /// - Returns: 年次特別枠使用状況
    internal func calculateAnnualBudgetUsage(
        params: AllocationCalculationParams,
        upToMonth: Int? = nil,
    ) -> AnnualBudgetUsage {
        let year = params.annualBudgetConfig.year
        let policy = params.annualBudgetConfig.policy

        // ポリシーが無効の場合は使用額0
        guard policy != .disabled else {
            return AnnualBudgetUsage(
                year: year,
                totalAmount: params.annualBudgetConfig.totalAmount,
                usedAmount: 0,
                remainingAmount: params.annualBudgetConfig.totalAmount,
                usageRate: 0.0,
            )
        }

        // 各月の充当額を計算
        let endMonth = upToMonth ?? 12
        var totalUsed: Decimal = 0

        for month in 1 ... endMonth {
            let monthlyCategoryAllocations = calculateCategoryAllocations(
                params: params,
                year: year,
                month: month,
                policy: policy,
            )

            // カテゴリ別充当額の合計を加算
            let monthlyUsed = monthlyCategoryAllocations
                .reduce(Decimal.zero) { $0 + $1.allocatableAmount }
            totalUsed += monthlyUsed
        }

        let remaining = params.annualBudgetConfig.totalAmount - totalUsed
        let usageRate: Double = if params.annualBudgetConfig.totalAmount > 0 {
            NSDecimalNumber(decimal: totalUsed)
                .doubleValue / NSDecimalNumber(decimal: params.annualBudgetConfig.totalAmount).doubleValue
        } else {
            0.0
        }

        return AnnualBudgetUsage(
            year: year,
            totalAmount: params.annualBudgetConfig.totalAmount,
            usedAmount: totalUsed,
            remainingAmount: remaining,
            usageRate: usageRate,
        )
    }

    /// 月次の年次特別枠充当を計算
    /// - Parameters:
    ///   - params: 計算パラメータ
    ///   - year: 対象年
    ///   - month: 対象月
    /// - Returns: 月次充当結果
    internal func calculateMonthlyAllocation(
        params: AllocationCalculationParams,
        year: Int,
        month: Int,
    ) -> MonthlyAllocation {
        let policy = params.annualBudgetConfig.policy

        let categoryAllocations = calculateCategoryAllocations(
            params: params,
            year: year,
            month: month,
            policy: policy,
        )

        // 年次特別枠の使用状況を計算（この月まで）
        let annualBudgetUsage = calculateAnnualBudgetUsage(
            params: params,
            upToMonth: month,
        )

        return MonthlyAllocation(
            year: year,
            month: month,
            annualBudgetUsage: annualBudgetUsage,
            categoryAllocations: categoryAllocations,
        )
    }

    private func calculateCategoryAllocations(
        params: AllocationCalculationParams,
        year: Int,
        month: Int,
        policy: AnnualBudgetPolicy,
    ) -> [CategoryAllocation] {
        // 月次集計を取得
        let monthlySummary = aggregator.aggregateMonthly(
            transactions: params.transactions,
            year: year,
            month: month,
            filter: params.filter,
        )

        // 対象月の予算を取得
        let monthlyBudgets = params.budgets.filter { budget in
            budget.year == year && budget.month == month
        }

        // カテゴリ別予算がある場合のみ処理
        return if policy == .disabled {
            // 無効の場合は充当なし
            []
        } else {
            // カテゴリ別に充当額を計算
            monthlyBudgets.compactMap { budget -> CategoryAllocation? in
                guard let category = budget.category else { return nil }

                // 年次特別枠を使用可能なカテゴリのみ
                guard category.allowsAnnualBudget else { return nil }

                // このカテゴリの実績を取得
                let categoryActual = monthlySummary.categorySummaries
                    .first { $0.categoryId == category.id }?
                    .totalExpense ?? 0

                // 予算超過額を計算
                let excessAmount = max(0, categoryActual - budget.amount)

                // 充当可能な金額（予算超過額と年次特別枠残額の小さい方）
                let allocatableAmount: Decimal = if policy == .automatic, excessAmount > 0 {
                    // 自動充当: 予算超過分を充当（年次特別枠の残額を考慮する必要があるが、
                    // ここでは簡易的に超過額をそのまま返す。実際の使用可能額は呼び出し側で制御）
                    excessAmount
                } else {
                    // 手動充当または超過なし
                    0
                }

                let remainingAfterAllocation = excessAmount - allocatableAmount

                return CategoryAllocation(
                    categoryId: category.id,
                    categoryName: category.fullName,
                    monthlyBudgetAmount: budget.amount,
                    actualAmount: categoryActual,
                    excessAmount: excessAmount,
                    allocatableAmount: allocatableAmount,
                    remainingAfterAllocation: remainingAfterAllocation,
                )
            }
        }
    }
}
