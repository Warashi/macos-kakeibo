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

// MARK: - BudgetCalculator

/// 予算計算サービス
///
/// 予算の使用状況を計算します。
/// - 予算使用率の計算
/// - 残額計算
/// - カテゴリ別予算チェック
internal struct BudgetCalculator: Sendable {
    private let aggregator: TransactionAggregator

    internal init() {
        self.aggregator = TransactionAggregator()
    }

    /// 単一の予算計算を実行
    /// - Parameters:
    ///   - budgetAmount: 予算額
    ///   - actualAmount: 実績額（支出）
    /// - Returns: 予算計算結果
    internal func calculate(
        budgetAmount: Decimal,
        actualAmount: Decimal,
    ) -> BudgetCalculation {
        let remaining = budgetAmount - actualAmount
        let isOverBudget = actualAmount > budgetAmount

        // 使用率を計算（0で割らないようにチェック）
        let usageRate: Double
        if budgetAmount > 0 {
            let rate = NSDecimalNumber(decimal: actualAmount)
                .doubleValue / NSDecimalNumber(decimal: budgetAmount).doubleValue
            usageRate = max(0.0, rate) // 負の値は0にする
        } else {
            usageRate = 0.0
        }

        return BudgetCalculation(
            budgetAmount: budgetAmount,
            actualAmount: actualAmount,
            remainingAmount: remaining,
            usageRate: usageRate,
            isOverBudget: isOverBudget,
        )
    }

    /// 月次予算計算を実行
    /// - Parameters:
    ///   - transactions: 取引リスト
    ///   - budgets: 予算リスト
    ///   - year: 対象年
    ///   - month: 対象月
    ///   - filter: 集計フィルタ
    /// - Returns: 月次予算計算結果
    internal func calculateMonthlyBudget(
        transactions: [Transaction],
        budgets: [Budget],
        year: Int,
        month: Int,
        filter: AggregationFilter = .default,
    ) -> MonthlyBudgetCalculation {
        // 月次集計を取得
        let monthlySummary = aggregator.aggregateMonthly(
            transactions: transactions,
            year: year,
            month: month,
            filter: filter,
        )

        // 対象月の予算を取得
        let monthlyBudgets = budgets.filter { budget in
            budget.contains(year: year, month: month)
        }

        // 全体予算（categoryがnilのもの）
        let overallBudget = monthlyBudgets.first { $0.category == nil }
        let overallCalculation: BudgetCalculation? = if let budget = overallBudget {
            calculate(
                budgetAmount: budget.amount,
                actualAmount: monthlySummary.totalExpense,
            )
        } else {
            nil
        }

        // カテゴリ別予算計算
        let categoryCalculations = monthlyBudgets.compactMap { budget -> CategoryBudgetCalculation? in
            guard let category = budget.category else { return nil }

            // このカテゴリの実績を取得
            let categoryActual = monthlySummary.categorySummaries
                .first { $0.categoryId == category.id }?
                .totalExpense ?? 0

            let calculation = calculate(
                budgetAmount: budget.amount,
                actualAmount: categoryActual,
            )

            return CategoryBudgetCalculation(
                categoryId: category.id,
                categoryName: category.fullName,
                calculation: calculation,
            )
        }

        return MonthlyBudgetCalculation(
            year: year,
            month: month,
            overallCalculation: overallCalculation,
            categoryCalculations: categoryCalculations,
        )
    }

    /// カテゴリ別の予算チェック
    /// - Parameters:
    ///   - category: 対象カテゴリ
    ///   - amount: 追加する金額
    ///   - currentExpense: 現在の支出額
    ///   - budgetAmount: 予算額
    /// - Returns: 予算超過するか
    internal func willExceedBudget(
        category: Category,
        amount: Decimal,
        currentExpense: Decimal,
        budgetAmount: Decimal,
    ) -> Bool {
        let newExpense = currentExpense + amount
        return newExpense > budgetAmount
    }
}
