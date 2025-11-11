import Foundation

// MARK: - BudgetCalculator

/// 予算計算サービス
///
/// 予算の使用状況を計算します。
/// - 予算使用率の計算
/// - 残額計算
/// - カテゴリ別予算チェック
/// - 特別支払い積立計算
internal struct BudgetCalculator: Sendable {
    private let aggregator: TransactionAggregator
    private let cache: BudgetCalculationCache

    internal init(
        aggregator: TransactionAggregator = TransactionAggregator(),
        cache: BudgetCalculationCache = BudgetCalculationCache()
    ) {
        self.aggregator = aggregator
        self.cache = cache
    }

    internal func invalidateCaches(targets: BudgetCalculationCache.Target = .all) {
        cache.invalidate(targets: targets)
    }

    internal func cacheMetrics() -> BudgetCalculationCacheMetrics {
        cache.metricsSnapshot
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
        excludedCategoryIds: Set<UUID> = [],
    ) -> MonthlyBudgetCalculation {
        let context = MonthlyBudgetComputationContext(
            transactions: transactions,
            budgets: budgets,
            year: year,
            month: month,
            filter: filter,
            excludedCategoryIds: excludedCategoryIds
        )
        let cacheKey = makeMonthlyBudgetCacheKey(context: context)
        if let cached = cache.cachedMonthlyBudget(for: cacheKey) {
            return cached
        }

        let monthlySummary = aggregateMonthlySummary(context: context)
        let monthlyBudgets = budgetsForMonth(context: context)
        let overallCalculation = overallMonthlyCalculation(
            monthlyBudgets: monthlyBudgets,
            summary: monthlySummary,
            excludedCategoryIds: context.excludedCategoryIds
        )
        let categoryCalculations = categoryBudgetCalculations(
            monthlyBudgets: monthlyBudgets,
            summary: monthlySummary
        )

        let result = MonthlyBudgetCalculation(
            year: year,
            month: month,
            overallCalculation: overallCalculation,
            categoryCalculations: categoryCalculations,
        )
        cache.storeMonthlyBudget(result, for: cacheKey)
        return result
    }

    private func makeMonthlyBudgetCacheKey(
        context: MonthlyBudgetComputationContext
    ) -> MonthlyBudgetCacheKey {
        MonthlyBudgetCacheKey(
            year: context.year,
            month: context.month,
            filter: FilterSignature(filter: context.filter),
            excludedCategoriesSignature: BudgetCalculationCacheHasher
                .excludedCategoriesSignature(for: context.excludedCategoryIds),
            transactionsVersion: BudgetCalculationCacheHasher.transactionsVersion(for: context.transactions),
            budgetsVersion: BudgetCalculationCacheHasher.budgetsVersion(for: context.budgets)
        )
    }

    private func aggregateMonthlySummary(
        context: MonthlyBudgetComputationContext
    ) -> MonthlySummary {
        aggregator.aggregateMonthly(
            transactions: context.transactions,
            year: context.year,
            month: context.month,
            filter: context.filter
        )
    }

    private func budgetsForMonth(
        context: MonthlyBudgetComputationContext
    ) -> [Budget] {
        context.budgets.filter { $0.contains(year: context.year, month: context.month) }
    }

    private func overallMonthlyCalculation(
        monthlyBudgets: [Budget],
        summary: MonthlySummary,
        excludedCategoryIds: Set<UUID>
    ) -> BudgetCalculation? {
        guard let budget = monthlyBudgets.first(where: { $0.category == nil }) else {
            return nil
        }
        let excludedExpense = excludedExpense(
            from: summary,
            excludedCategoryIds: excludedCategoryIds
        )
        let adjustedTotalExpense = summary.totalExpense - excludedExpense
        return calculate(
            budgetAmount: budget.amount,
            actualAmount: max(0, adjustedTotalExpense)
        )
    }

    private func excludedExpense(
        from summary: MonthlySummary,
        excludedCategoryIds: Set<UUID>
    ) -> Decimal {
        summary.categorySummaries.reduce(into: Decimal.zero) { partial, summary in
            guard let categoryId = summary.categoryId,
                  excludedCategoryIds.contains(categoryId) else {
                return
            }
            partial += summary.totalExpense
        }
    }

    private func categoryBudgetCalculations(
        monthlyBudgets: [Budget],
        summary: MonthlySummary
    ) -> [CategoryBudgetCalculation] {
        monthlyBudgets.compactMap { budget -> CategoryBudgetCalculation? in
            guard let category = budget.category else { return nil }
            let categoryActual = categoryActualAmount(
                for: category,
                summary: summary
            )
            let calculation = calculate(
                budgetAmount: budget.amount,
                actualAmount: categoryActual
            )
            return CategoryBudgetCalculation(
                categoryId: category.id,
                categoryName: category.fullName,
                calculation: calculation
            )
        }
    }

    private func categoryActualAmount(
        for category: Category,
        summary: MonthlySummary
    ) -> Decimal {
        if category.isMajor {
            let childCategoryIds = Set(category.children.map(\.id))
            return summary.categorySummaries
                .filter { summary in
                    summary.categoryId == category.id
                        || (summary.categoryId.map { childCategoryIds.contains($0) } ?? false)
                }
                .reduce(Decimal.zero) { $0 + $1.totalExpense }
        }
        return summary.categorySummaries
            .first { $0.categoryId == category.id }?
            .totalExpense ?? 0
    }

    private struct MonthlyBudgetComputationContext {
        let transactions: [Transaction]
        let budgets: [Budget]
        let year: Int
        let month: Int
        let filter: AggregationFilter
        let excludedCategoryIds: Set<UUID>
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

    // MARK: - 特別支払い積立計算

    /// 全特別支払いの積立状況を計算
    /// - Parameters:
    ///   - definitions: 特別支払い定義リスト
    ///   - balances: 積立残高リスト
    ///   - year: 対象年
    ///   - month: 対象月
    /// - Returns: 積立状況計算結果リスト
    internal func calculateSpecialPaymentSavings(
        definitions: [SpecialPaymentDefinition],
        balances: [SpecialPaymentSavingBalance],
        year: Int,
        month: Int,
    ) -> [SpecialPaymentSavingsCalculation] {
        let cacheKey = SpecialPaymentSavingsCacheKey(
            year: year,
            month: month,
            definitionsVersion: BudgetCalculationCacheHasher.definitionsVersion(definitions),
            balancesVersion: BudgetCalculationCacheHasher.balancesVersion(for: balances)
        )
        if let cached = cache.cachedSpecialPaymentSavings(for: cacheKey) {
            return cached
        }

        // 残高をdefinitionIdでマップ化
        let balanceMap = Dictionary(
            uniqueKeysWithValues: balances.map { ($0.definition.id, $0) },
        )

        let calculations = definitions.map { definition in
            let balance = balanceMap[definition.id]
            let monthlySaving = definition.monthlySavingAmount
            let totalSaved = balance?.totalSavedAmount ?? 0
            let totalPaid = balance?.totalPaidAmount ?? 0
            let balanceAmount = totalSaved.safeSubtract(totalPaid)

            // 次回発生予定のOccurrenceを取得
            let upcomingOccurrences = definition.occurrences.filter { occurrence in
                occurrence.scheduledDate >= Date() && occurrence.status != .completed
            }
            let nextOccurrence = upcomingOccurrences.first?.scheduledDate

            return SpecialPaymentSavingsCalculation(
                definitionId: definition.id,
                name: definition.name,
                monthlySaving: monthlySaving,
                totalSaved: totalSaved,
                totalPaid: totalPaid,
                balance: balanceAmount,
                nextOccurrence: nextOccurrence,
            )
        }
        cache.storeSpecialPaymentSavings(calculations, for: cacheKey)
        return calculations
    }

    /// 月次に組み込むべき積立金額の合計を計算
    /// - Parameters:
    ///   - definitions: 特別支払い定義リスト
    ///   - year: 対象年
    ///   - month: 対象月
    /// - Returns: 月次積立金額の合計
    internal func calculateMonthlySavingsAllocation(
        definitions: [SpecialPaymentDefinition],
        year: Int,
        month: Int,
    ) -> Decimal {
        let cacheKey = SavingsAllocationCacheKey(
            year: year,
            month: month,
            definitionsVersion: BudgetCalculationCacheHasher.definitionsVersion(definitions)
        )
        if let cached = cache.cachedMonthlySavingsAllocation(for: cacheKey) {
            return cached
        }

        // 積立が有効な定義のみをフィルタリング
        let activeDefinitions = definitions.filter { definition in
            definition.savingStrategy != .disabled
        }

        // 各定義の月次積立額を合計
        let total = activeDefinitions.reduce(Decimal(0)) { sum, definition in
            sum.safeAdd(definition.monthlySavingAmount)
        }
        cache.storeMonthlySavingsAllocation(total, for: cacheKey)
        return total
    }

    /// カテゴリ別の積立金額を計算
    /// - Parameters:
    ///   - definitions: 特別支払い定義リスト
    ///   - year: 対象年
    ///   - month: 対象月
    /// - Returns: カテゴリIDと積立金額のマップ
    internal func calculateCategorySavingsAllocation(
        definitions: [SpecialPaymentDefinition],
        year: Int,
        month: Int,
    ) -> [UUID: Decimal] {
        let cacheKey = SavingsAllocationCacheKey(
            year: year,
            month: month,
            definitionsVersion: BudgetCalculationCacheHasher.definitionsVersion(definitions)
        )
        if let cached = cache.cachedCategorySavingsAllocation(for: cacheKey) {
            return cached
        }

        // カテゴリが設定されていて、積立が有効な定義のみをフィルタリング
        let categorizedDefinitions = definitions.filter { definition in
            definition.category != nil && definition.savingStrategy != .disabled
        }

        // カテゴリごとに積立額を集計
        var categoryAllocations: [UUID: Decimal] = [:]
        for definition in categorizedDefinitions {
            guard let categoryId = definition.category?.id else { continue }

            let currentAmount = categoryAllocations[categoryId] ?? 0
            let newAmount = currentAmount.safeAdd(definition.monthlySavingAmount)
            categoryAllocations[categoryId] = newAmount
        }

        cache.storeCategorySavingsAllocation(categoryAllocations, for: cacheKey)
        return categoryAllocations
    }
}
