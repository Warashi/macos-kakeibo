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

// MARK: - 特別支払い積立計算結果型

/// 特別支払い積立計算結果
internal struct SpecialPaymentSavingsCalculation: Sendable {
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
        let cacheKey = MonthlyBudgetCacheKey(
            year: year,
            month: month,
            filter: FilterSignature(filter: filter),
            excludedCategoriesSignature: signature(for: excludedCategoryIds),
            transactionsVersion: version(for: transactions),
            budgetsVersion: version(for: budgets)
        )
        if let cached = cache.cachedMonthlyBudget(for: cacheKey) {
            return cached
        }

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
        let excludedExpense = monthlySummary.categorySummaries.reduce(Decimal.zero) { partial, summary in
            guard let categoryId = summary.categoryId,
                  excludedCategoryIds.contains(categoryId) else {
                return partial
            }
            return partial + summary.totalExpense
        }
        let adjustedTotalExpense = monthlySummary.totalExpense - excludedExpense

        let overallCalculation: BudgetCalculation? = if let budget = overallBudget {
            calculate(
                budgetAmount: budget.amount,
                actualAmount: max(0, adjustedTotalExpense),
            )
        } else {
            nil
        }

        // カテゴリ別予算計算
        let categoryCalculations = monthlyBudgets.compactMap { budget -> CategoryBudgetCalculation? in
            guard let category = budget.category else { return nil }

            // このカテゴリの実績を取得
            let categoryActual: Decimal
            if category.isMajor {
                // 大項目の場合：大項目自身と全ての子カテゴリの実績を合計
                let childCategoryIds = Set(category.children.map(\.id))
                categoryActual = monthlySummary.categorySummaries
                    .filter { summary in
                        // 大項目自身のID、または子カテゴリのIDと一致するものを集計
                        summary.categoryId == category
                            .id || (summary.categoryId.map { childCategoryIds.contains($0) } ?? false)
                    }
                    .reduce(Decimal.zero) { $0 + $1.totalExpense }
            } else {
                // 中項目の場合：そのカテゴリIDと完全一致するもののみ
                categoryActual = monthlySummary.categorySummaries
                    .first { $0.categoryId == category.id }?
                    .totalExpense ?? 0
            }

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

        let result = MonthlyBudgetCalculation(
            year: year,
            month: month,
            overallCalculation: overallCalculation,
            categoryCalculations: categoryCalculations,
        )
        cache.storeMonthlyBudget(result, for: cacheKey)
        return result
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
            definitionsVersion: definitionsVersion(definitions),
            balancesVersion: version(for: balances)
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
            definitionsVersion: definitionsVersion(definitions)
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
            definitionsVersion: definitionsVersion(definitions)
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

// MARK: - Cache Infrastructure

internal struct MonthlyBudgetCacheKey: Hashable {
    let year: Int
    let month: Int
    let filter: FilterSignature
    let excludedCategoriesSignature: Int
    let transactionsVersion: Int
    let budgetsVersion: Int
}

internal struct SpecialPaymentSavingsCacheKey: Hashable {
    let year: Int
    let month: Int
    let definitionsVersion: Int
    let balancesVersion: Int
}

internal struct SavingsAllocationCacheKey: Hashable {
    let year: Int
    let month: Int
    let definitionsVersion: Int
}

private struct FilterSignature: Hashable {
    let includeOnlyCalculationTarget: Bool
    let excludeTransfers: Bool
    let financialInstitutionId: UUID?
    let categoryId: UUID?

    init(filter: AggregationFilter) {
        self.includeOnlyCalculationTarget = filter.includeOnlyCalculationTarget
        self.excludeTransfers = filter.excludeTransfers
        self.financialInstitutionId = filter.financialInstitutionId
        self.categoryId = filter.categoryId
    }
}

internal struct BudgetCalculationCacheMetrics: Sendable {
    internal let monthlyBudgetHits: Int
    internal let monthlyBudgetMisses: Int
    internal let specialPaymentHits: Int
    internal let specialPaymentMisses: Int
    internal let monthlySavingsHits: Int
    internal let monthlySavingsMisses: Int
    internal let categorySavingsHits: Int
    internal let categorySavingsMisses: Int
}

private func signature(for categories: Set<UUID>) -> Int {
    var hasher = Hasher()
    hasher.combine(categories.count)
    for id in categories.sorted(by: { $0.uuidString < $1.uuidString }) {
        hasher.combine(id)
    }
    return hasher.finalize()
}

private func version(for transactions: [Transaction]) -> Int {
    versionHash(for: transactions, id: { $0.id }, updatedAt: { $0.updatedAt })
}

private func version(for budgets: [Budget]) -> Int {
    versionHash(for: budgets, id: { $0.id }, updatedAt: { $0.updatedAt })
}

private func version(for balances: [SpecialPaymentSavingBalance]) -> Int {
    versionHash(for: balances, id: { $0.id }, updatedAt: { $0.updatedAt })
}

private func definitionsVersion(_ definitions: [SpecialPaymentDefinition]) -> Int {
    var hasher = Hasher()
    hasher.combine(definitions.count)

    let sortedDefinitions = definitions.sorted { $0.id.uuidString < $1.id.uuidString }
    for definition in sortedDefinitions {
        hasher.combine(definition.id)
        hasher.combine(definition.updatedAt.timeIntervalSinceReferenceDate)
        hasher.combine(definition.occurrences.count)
        if let latestOccurrence = definition.occurrences.map(\.updatedAt).max() {
            hasher.combine(latestOccurrence.timeIntervalSinceReferenceDate)
        }
    }

    return hasher.finalize()
}

private func versionHash<T>(
    for items: [T],
    id: (T) -> UUID,
    updatedAt: (T) -> Date
) -> Int {
    var hasher = Hasher()
    hasher.combine(items.count)
    let sortedItems = items.sorted { id($0).uuidString < id($1).uuidString }
    for item in sortedItems {
        hasher.combine(id(item))
        hasher.combine(updatedAt(item).timeIntervalSinceReferenceDate)
    }
    return hasher.finalize()
}

final class BudgetCalculationCache: @unchecked Sendable {
    private struct StorageMetrics {
        var monthlyBudgetHits: Int = 0
        var monthlyBudgetMisses: Int = 0
        var specialPaymentHits: Int = 0
        var specialPaymentMisses: Int = 0
        var monthlySavingsHits: Int = 0
        var monthlySavingsMisses: Int = 0
        var categorySavingsHits: Int = 0
        var categorySavingsMisses: Int = 0
    }

    internal struct Target: OptionSet {
        internal let rawValue: Int

        internal static let monthlyBudget = Target(rawValue: 1 << 0)
        internal static let specialPaymentSavings = Target(rawValue: 1 << 1)
        internal static let monthlySavings = Target(rawValue: 1 << 2)
        internal static let categorySavings = Target(rawValue: 1 << 3)
        internal static let all: Target = [.monthlyBudget, .specialPaymentSavings, .monthlySavings, .categorySavings]

        internal init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    private let lock = NSLock()
    private var monthlyBudgetCache: [MonthlyBudgetCacheKey: MonthlyBudgetCalculation] = [:]
    private var specialPaymentSavingsCache: [SpecialPaymentSavingsCacheKey: [SpecialPaymentSavingsCalculation]] = [:]
    private var monthlySavingsCache: [SavingsAllocationCacheKey: Decimal] = [:]
    private var categorySavingsCache: [SavingsAllocationCacheKey: [UUID: Decimal]] = [:]
    private var metrics = StorageMetrics()

    internal var metricsSnapshot: BudgetCalculationCacheMetrics {
        lock.withLock {
            BudgetCalculationCacheMetrics(
                monthlyBudgetHits: metrics.monthlyBudgetHits,
                monthlyBudgetMisses: metrics.monthlyBudgetMisses,
                specialPaymentHits: metrics.specialPaymentHits,
                specialPaymentMisses: metrics.specialPaymentMisses,
                monthlySavingsHits: metrics.monthlySavingsHits,
                monthlySavingsMisses: metrics.monthlySavingsMisses,
                categorySavingsHits: metrics.categorySavingsHits,
                categorySavingsMisses: metrics.categorySavingsMisses
            )
        }
    }

    internal func cachedMonthlyBudget(for key: MonthlyBudgetCacheKey) -> MonthlyBudgetCalculation? {
        lock.withLock {
            if let value = monthlyBudgetCache[key] {
                metrics.monthlyBudgetHits += 1
                return value
            }
            metrics.monthlyBudgetMisses += 1
            return nil
        }
    }

    internal func storeMonthlyBudget(_ value: MonthlyBudgetCalculation, for key: MonthlyBudgetCacheKey) {
        lock.withLock {
            monthlyBudgetCache[key] = value
        }
    }

    internal func cachedSpecialPaymentSavings(
        for key: SpecialPaymentSavingsCacheKey
    ) -> [SpecialPaymentSavingsCalculation]? {
        lock.withLock {
            if let value = specialPaymentSavingsCache[key] {
                metrics.specialPaymentHits += 1
                return value
            }
            metrics.specialPaymentMisses += 1
            return nil
        }
    }

    internal func storeSpecialPaymentSavings(
        _ value: [SpecialPaymentSavingsCalculation],
        for key: SpecialPaymentSavingsCacheKey
    ) {
        lock.withLock {
            specialPaymentSavingsCache[key] = value
        }
    }

    internal func cachedMonthlySavingsAllocation(for key: SavingsAllocationCacheKey) -> Decimal? {
        lock.withLock {
            if let value = monthlySavingsCache[key] {
                metrics.monthlySavingsHits += 1
                return value
            }
            metrics.monthlySavingsMisses += 1
            return nil
        }
    }

    internal func storeMonthlySavingsAllocation(_ value: Decimal, for key: SavingsAllocationCacheKey) {
        lock.withLock {
            monthlySavingsCache[key] = value
        }
    }

    internal func cachedCategorySavingsAllocation(
        for key: SavingsAllocationCacheKey
    ) -> [UUID: Decimal]? {
        lock.withLock {
            if let value = categorySavingsCache[key] {
                metrics.categorySavingsHits += 1
                return value
            }
            metrics.categorySavingsMisses += 1
            return nil
        }
    }

    internal func storeCategorySavingsAllocation(
        _ value: [UUID: Decimal],
        for key: SavingsAllocationCacheKey
    ) {
        lock.withLock {
            categorySavingsCache[key] = value
        }
    }

    internal func invalidate(targets: Target) {
        lock.withLock {
            if targets.contains(.monthlyBudget) {
                monthlyBudgetCache.removeAll()
            }
            if targets.contains(.specialPaymentSavings) {
                specialPaymentSavingsCache.removeAll()
            }
            if targets.contains(.monthlySavings) {
                monthlySavingsCache.removeAll()
            }
            if targets.contains(.categorySavings) {
                categorySavingsCache.removeAll()
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ execute: () -> T) -> T {
        lock()
        defer { unlock() }
        return execute()
    }
}
