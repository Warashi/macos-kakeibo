import Foundation

// MARK: - 予算計算結果型

/// 予算計算結果
public struct BudgetCalculation: Sendable {
    /// 予算額
    public let budgetAmount: Decimal

    /// 実績額（支出）
    public let actualAmount: Decimal

    /// 残額（予算額 - 実績額）
    public let remainingAmount: Decimal

    /// 使用率（0.0 〜 1.0）
    public let usageRate: Double

    /// 予算超過フラグ
    public let isOverBudget: Bool

    public init(
        budgetAmount: Decimal,
        actualAmount: Decimal,
        remainingAmount: Decimal,
        usageRate: Double,
        isOverBudget: Bool,
    ) {
        self.budgetAmount = budgetAmount
        self.actualAmount = actualAmount
        self.remainingAmount = remainingAmount
        self.usageRate = usageRate
        self.isOverBudget = isOverBudget
    }
}

/// カテゴリ別予算計算結果
public struct CategoryBudgetCalculation: Sendable {
    /// カテゴリID
    public let categoryId: UUID

    /// カテゴリ名
    public let categoryName: String

    /// 予算計算結果
    public let calculation: BudgetCalculation

    public init(
        categoryId: UUID,
        categoryName: String,
        calculation: BudgetCalculation,
    ) {
        self.categoryId = categoryId
        self.calculation = calculation
        self.categoryName = categoryName
    }
}

/// 月次予算計算結果
public struct MonthlyBudgetCalculation: Sendable {
    /// 対象年
    public let year: Int

    /// 対象月
    public let month: Int

    /// 全体予算計算
    public let overallCalculation: BudgetCalculation?

    /// カテゴリ別予算計算
    public let categoryCalculations: [CategoryBudgetCalculation]

    public init(
        year: Int,
        month: Int,
        overallCalculation: BudgetCalculation?,
        categoryCalculations: [CategoryBudgetCalculation],
    ) {
        self.year = year
        self.month = month
        self.overallCalculation = overallCalculation
        self.categoryCalculations = categoryCalculations
    }
}

// MARK: - BudgetCalculator

/// 予算計算サービス
///
/// 予算の使用状況を計算します。
/// - 予算使用率の計算
/// - 残額計算
/// - カテゴリ別予算チェック
public struct BudgetCalculator: Sendable {
    private let aggregator: TransactionAggregator

    public init() {
        self.aggregator = TransactionAggregator()
    }

    /// 単一の予算計算を実行
    /// - Parameters:
    ///   - budgetAmount: 予算額
    ///   - actualAmount: 実績額（支出）
    /// - Returns: 予算計算結果
    public func calculate(
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
    public func calculateMonthlyBudget(
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
            budget.year == year && budget.month == month
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
    public func willExceedBudget(
        category: Category,
        amount: Decimal,
        currentExpense: Decimal,
        budgetAmount: Decimal,
    ) -> Bool {
        let newExpense = currentExpense + amount
        return newExpense > budgetAmount
    }
}
