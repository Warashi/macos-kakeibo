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

/// カテゴリ別累積計算用の内部構造体
private struct CategoryAllocationAccumulator {
    let categoryId: UUID
    let categoryName: String
    let annualBudgetAmount: Decimal
    var monthlyBudgetAmount: Decimal
    var actualAmount: Decimal
    var excessAmount: Decimal
    var allocatableAmount: Decimal
    var remainingAfterAllocation: Decimal
}

/// 累積計算パラメータ
private struct AccumulationParams {
    let params: AllocationCalculationParams
    let year: Int
    let endMonth: Int
    let policy: AnnualBudgetPolicy
    let annualBudgetConfig: AnnualBudgetConfig
}

/// 充当金額計算結果
private struct AllocationAmounts {
    let allocatable: Decimal
    let excess: Decimal
    let remainingAfterAllocation: Decimal
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
    private let budgetCalculator: BudgetCalculator

    internal init() {
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
                categoryAllocations: [],
            )
        }

        let endMonth = upToMonth ?? 12
        let accumulationParams = AccumulationParams(
            params: params,
            year: year,
            endMonth: endMonth,
            policy: policy,
            annualBudgetConfig: params.annualBudgetConfig,
        )
        let result = accumulateCategoryAllocations(accumulationParams: accumulationParams)

        let remaining = params.annualBudgetConfig.totalAmount - result.totalUsed
        let usageRate: Double = if params.annualBudgetConfig.totalAmount > 0 {
            NSDecimalNumber(decimal: result.totalUsed)
                .doubleValue / NSDecimalNumber(decimal: params.annualBudgetConfig.totalAmount).doubleValue
        } else {
            0.0
        }

        return AnnualBudgetUsage(
            year: year,
            totalAmount: params.annualBudgetConfig.totalAmount,
            usedAmount: result.totalUsed,
            remainingAmount: remaining,
            usageRate: usageRate,
            categoryAllocations: result.categoryAllocations,
        )
    }

    private func accumulateCategoryAllocations(
        accumulationParams: AccumulationParams,
    ) -> (totalUsed: Decimal, categoryAllocations: [CategoryAllocation]) {
        var totalUsed: Decimal = 0

        // 年次特別枠設定に登録されているすべてのカテゴリを初期化
        var categoryAccumulator: [UUID: CategoryAllocationAccumulator] = [:]
        for allocation in accumulationParams.annualBudgetConfig.allocations {
            let category = allocation.category
            categoryAccumulator[category.id] = CategoryAllocationAccumulator(
                categoryId: category.id,
                categoryName: category.fullName,
                annualBudgetAmount: allocation.amount,
                monthlyBudgetAmount: 0,
                actualAmount: 0,
                excessAmount: 0,
                allocatableAmount: 0,
                remainingAfterAllocation: 0,
            )
        }

        for month in 1 ... accumulationParams.endMonth {
            let monthlyCategoryAllocations = calculateCategoryAllocations(
                params: accumulationParams.params,
                year: accumulationParams.year,
                month: month,
                policy: accumulationParams.policy,
            )

            // カテゴリ別充当額の合計を加算
            let monthlyUsed = monthlyCategoryAllocations
                .reduce(Decimal.zero) { $0 + $1.allocatableAmount }
            totalUsed += monthlyUsed

            // カテゴリ別に累積
            accumulateCategory(
                allocations: monthlyCategoryAllocations,
                into: &categoryAccumulator,
            )
        }

        // カテゴリ別累積をCategoryAllocationに変換
        let categoryAllocations = categoryAccumulator.values
            .map { accumulator in
                CategoryAllocation(
                    categoryId: accumulator.categoryId,
                    categoryName: accumulator.categoryName,
                    annualBudgetAmount: accumulator.annualBudgetAmount,
                    monthlyBudgetAmount: accumulator.monthlyBudgetAmount,
                    actualAmount: accumulator.actualAmount,
                    excessAmount: accumulator.excessAmount,
                    allocatableAmount: accumulator.allocatableAmount,
                    remainingAfterAllocation: accumulator.remainingAfterAllocation,
                )
            }
            .sorted { $0.categoryName < $1.categoryName }

        return (totalUsed, categoryAllocations)
    }

    private func accumulateCategory(
        allocations: [CategoryAllocation],
        into categoryAccumulator: inout [UUID: CategoryAllocationAccumulator],
    ) {
        for allocation in allocations {
            if var accumulator = categoryAccumulator[allocation.categoryId] {
                accumulator.monthlyBudgetAmount += allocation.monthlyBudgetAmount
                accumulator.actualAmount += allocation.actualAmount
                accumulator.excessAmount += allocation.excessAmount
                accumulator.allocatableAmount += allocation.allocatableAmount
                accumulator.remainingAfterAllocation += allocation.remainingAfterAllocation
                categoryAccumulator[allocation.categoryId] = accumulator
            } else {
                categoryAccumulator[allocation.categoryId] = CategoryAllocationAccumulator(
                    categoryId: allocation.categoryId,
                    categoryName: allocation.categoryName,
                    annualBudgetAmount: allocation.annualBudgetAmount,
                    monthlyBudgetAmount: allocation.monthlyBudgetAmount,
                    actualAmount: allocation.actualAmount,
                    excessAmount: allocation.excessAmount,
                    allocatableAmount: allocation.allocatableAmount,
                    remainingAfterAllocation: allocation.remainingAfterAllocation,
                )
            }
        }
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
        let filteredTransactions = filterTransactions(
            transactions: params.transactions,
            year: year,
            month: month,
            filter: params.filter,
        )

        let expenseMaps = makeActualExpenseMaps(from: filteredTransactions)
        let actualExpenseMap = expenseMaps.categoryExpenses
        let childExpenseMap = expenseMaps.childExpenseByParent
        let childFallbackMap = buildChildFallbackMap(from: filteredTransactions)
        let monthlyBudgets = params.budgets.filter { $0.contains(year: year, month: month) }
        let allocationAmounts = allocationAmountMap(from: params.annualBudgetConfig)
        let policyContext = PolicyContext(
            overrides: policyOverrideMap(from: params.annualBudgetConfig),
            defaultPolicy: policy,
            allocationAmounts: allocationAmounts,
            allocatedCategoryIds: Set(allocationAmounts.keys),
        )

        if policy == .disabled, policyContext.overrides.isEmpty {
            return []
        }

        var allocations: [CategoryAllocation] = []
        var processedCategoryIds: Set<UUID> = []

        allocations.append(
            contentsOf: calculateAllocationsForMonthlyBudgets(
                budgets: monthlyBudgets,
                actualExpenseMap: actualExpenseMap,
                childExpenseMap: childExpenseMap,
                policyContext: policyContext,
                childFallbackMap: childFallbackMap,
                processedCategoryIds: &processedCategoryIds,
            ),
        )

        allocations.append(
            contentsOf: calculateAllocationsForFullCoverage(
                config: params.annualBudgetConfig,
                actualExpenseMap: actualExpenseMap,
                childExpenseMap: childExpenseMap,
                policyContext: policyContext,
                childFallbackMap: childFallbackMap,
                processedCategoryIds: &processedCategoryIds,
            ),
        )

        allocations.append(
            contentsOf: calculateAllocationsForUnbudgetedCategories(
                config: params.annualBudgetConfig,
                actualExpenseMap: actualExpenseMap,
                childExpenseMap: childExpenseMap,
                policyContext: policyContext,
                childFallbackMap: childFallbackMap,
                processedCategoryIds: &processedCategoryIds,
            ),
        )

        return allocations
    }

    private struct PolicyContext {
        let overrides: [UUID: AnnualBudgetPolicy]
        let defaultPolicy: AnnualBudgetPolicy
        let allocationAmounts: [UUID: Decimal]
        let allocatedCategoryIds: Set<UUID>
    }

    private func calculateAllocationsForMonthlyBudgets(
        budgets: [Budget],
        actualExpenseMap: [UUID: Decimal],
        childExpenseMap: [UUID: Decimal],
        policyContext: PolicyContext,
        childFallbackMap: [UUID: Set<UUID>],
        processedCategoryIds: inout Set<UUID>,
    ) -> [CategoryAllocation] {
        var allocations: [CategoryAllocation] = []

        for budget in budgets {
            guard let category = budget.category else { continue }

            let categoryId = category.id
            let isEligible = category.allowsAnnualBudget || policyContext.allocationAmounts[categoryId] != nil
            guard isEligible else { continue }
            let annualBudgetAmount = policyContext.allocationAmounts[categoryId] ?? 0
            let effectivePolicy = policyContext.overrides[categoryId] ?? policyContext.defaultPolicy
            guard effectivePolicy != .disabled else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                from: actualExpenseMap,
                childExpenseMap: childExpenseMap,
                childFallbackMap: childFallbackMap,
                allocatedCategoryIds: policyContext.allocatedCategoryIds,
            )

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: budget.amount,
                policy: effectivePolicy,
            )

            allocations.append(
                CategoryAllocation(
                    categoryId: categoryId,
                    categoryName: category.fullName,
                    annualBudgetAmount: annualBudgetAmount,
                    monthlyBudgetAmount: budget.amount,
                    actualAmount: actualAmount,
                    excessAmount: amounts.excess,
                    allocatableAmount: amounts.allocatable,
                    remainingAfterAllocation: amounts.remainingAfterAllocation,
                ),
            )

            processedCategoryIds.insert(categoryId)
        }

        return allocations
    }

    private func calculateAllocationsForUnbudgetedCategories(
        config: AnnualBudgetConfig,
        actualExpenseMap: [UUID: Decimal],
        childExpenseMap: [UUID: Decimal],
        policyContext: PolicyContext,
        childFallbackMap: [UUID: Set<UUID>],
        processedCategoryIds: inout Set<UUID>,
    ) -> [CategoryAllocation] {
        var allocations: [CategoryAllocation] = []

        for allocation in config.allocations {
            let category = allocation.category
            let categoryId = category.id
            guard !processedCategoryIds.contains(categoryId) else { continue }

            let effectivePolicy = policyContext.overrides[categoryId] ?? policyContext.defaultPolicy
            guard effectivePolicy != .disabled else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                from: actualExpenseMap,
                childExpenseMap: childExpenseMap,
                childFallbackMap: childFallbackMap,
                allocatedCategoryIds: policyContext.allocatedCategoryIds,
            )
            guard actualAmount > 0 else { continue }

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: 0,
                policy: effectivePolicy,
            )

            allocations.append(
                CategoryAllocation(
                    categoryId: categoryId,
                    categoryName: category.fullName,
                    annualBudgetAmount: allocation.amount,
                    monthlyBudgetAmount: 0,
                    actualAmount: actualAmount,
                    excessAmount: amounts.excess,
                    allocatableAmount: amounts.allocatable,
                    remainingAfterAllocation: amounts.remainingAfterAllocation,
                ),
            )

            processedCategoryIds.insert(categoryId)
        }

        return allocations
    }

    private func calculateAllocationsForFullCoverage(
        config: AnnualBudgetConfig,
        actualExpenseMap: [UUID: Decimal],
        childExpenseMap: [UUID: Decimal],
        policyContext: PolicyContext,
        childFallbackMap: [UUID: Set<UUID>],
        processedCategoryIds: inout Set<UUID>,
    ) -> [CategoryAllocation] {
        let fullCoverageAllocations = config.allocations
            .filter { $0.policyOverride == .fullCoverage }
            .sorted { lhs, rhs in lhs.category.fullName < rhs.category.fullName }

        var allocations: [CategoryAllocation] = []

        for allocation in fullCoverageAllocations {
            let category = allocation.category
            let categoryId = category.id
            guard !processedCategoryIds.contains(categoryId) else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                from: actualExpenseMap,
                childExpenseMap: childExpenseMap,
                childFallbackMap: childFallbackMap,
                allocatedCategoryIds: policyContext.allocatedCategoryIds,
            )
            guard actualAmount > 0 else { continue }

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: 0,
                policy: .fullCoverage,
            )

            allocations.append(
                CategoryAllocation(
                    categoryId: categoryId,
                    categoryName: category.fullName,
                    annualBudgetAmount: allocation.amount,
                    monthlyBudgetAmount: 0,
                    actualAmount: actualAmount,
                    excessAmount: amounts.excess,
                    allocatableAmount: amounts.allocatable,
                    remainingAfterAllocation: amounts.remainingAfterAllocation,
                ),
            )

            processedCategoryIds.insert(categoryId)
        }

        return allocations
    }

    private func calculateActualAmount(
        for category: Category,
        from actualExpenseMap: [UUID: Decimal],
        childExpenseMap: [UUID: Decimal],
        childFallbackMap: [UUID: Set<UUID>],
        allocatedCategoryIds: Set<UUID>,
    ) -> Decimal {
        let categoryId = category.id
        if category.isMajor {
            // 大項目の場合：子カテゴリのうち年次枠配分がないものだけを合算
            let childCategoryIds: Set<UUID>
            if category.children.isEmpty,
               let fallbackChildren = childFallbackMap[categoryId] {
                childCategoryIds = fallbackChildren
            } else {
                childCategoryIds = Set(category.children.map(\.id))
            }
            var total = actualExpenseMap[categoryId] ?? 0

            for childId in childCategoryIds where !allocatedCategoryIds.contains(childId) {
                total += actualExpenseMap[childId] ?? 0
            }

            if childCategoryIds.isEmpty {
                total += childExpenseMap[categoryId] ?? 0
            }

            return total
        } else {
            // 中項目の場合：そのカテゴリIDと完全一致するもののみ
            return actualExpenseMap[categoryId] ?? 0
        }
    }

    private func policyOverrideMap(from config: AnnualBudgetConfig) -> [UUID: AnnualBudgetPolicy] {
        config.allocations.reduce(into: [:]) { partialResult, allocation in
            guard let override = allocation.policyOverride else { return }
            partialResult[allocation.category.id] = override
        }
    }

    private func allocationAmountMap(from config: AnnualBudgetConfig) -> [UUID: Decimal] {
        config.allocations.reduce(into: [:]) { partialResult, allocation in
            partialResult[allocation.category.id] = allocation.amount
        }
    }

    private func calculateAllocationAmounts(
        actualAmount: Decimal,
        budgetAmount: Decimal,
        policy: AnnualBudgetPolicy,
    ) -> AllocationAmounts {
        switch policy {
        case .automatic:
            let excess = max(0, actualAmount - budgetAmount)
            return AllocationAmounts(
                allocatable: excess,
                excess: excess,
                remainingAfterAllocation: 0,
            )
        case .manual:
            let excess = max(0, actualAmount - budgetAmount)
            return AllocationAmounts(
                allocatable: 0,
                excess: excess,
                remainingAfterAllocation: excess,
            )
        case .disabled:
            return AllocationAmounts(
                allocatable: 0,
                excess: 0,
                remainingAfterAllocation: 0,
            )
        case .fullCoverage:
            return AllocationAmounts(
                allocatable: actualAmount,
                excess: actualAmount,
                remainingAfterAllocation: 0,
            )
        }
    }
}

// MARK: - Helper Functions

private func filterTransactions(
    transactions: [Transaction],
    year: Int,
    month: Int,
    filter: AggregationFilter,
) -> [Transaction] {
    transactions.filter { transaction in
        guard transaction.date.year == year,
              transaction.date.month == month else {
            return false
        }
        return matchesFilter(transaction: transaction, filter: filter)
    }
}

private func matchesFilter(
    transaction: Transaction,
    filter: AggregationFilter,
) -> Bool {
    if filter.includeOnlyCalculationTarget, !transaction.isIncludedInCalculation {
        return false
    }

    if filter.excludeTransfers, transaction.isTransfer {
        return false
    }

    if let institutionId = filter.financialInstitutionId {
        guard transaction.financialInstitution?.id == institutionId else {
            return false
        }
    }

    if let categoryId = filter.categoryId {
        let majorMatches = transaction.majorCategory?.id == categoryId
        let minorMatches = transaction.minorCategory?.id == categoryId
        guard majorMatches || minorMatches else {
            return false
        }
    }

    return true
}

private struct ActualExpenseMaps {
    let categoryExpenses: [UUID: Decimal]
    let childExpenseByParent: [UUID: Decimal]
}

private func makeActualExpenseMaps(from transactions: [Transaction]) -> ActualExpenseMaps {
    var categoryExpenses: [UUID: Decimal] = [:]
    var childExpenseByParent: [UUID: Decimal] = [:]

    for transaction in transactions where transaction.isExpense {
        let amount = abs(transaction.amount)

        if let minor = transaction.minorCategory {
            categoryExpenses[minor.id, default: 0] += amount
            let parentId = transaction.majorCategory?.id ?? minor.parent?.id
            if let parentId {
                childExpenseByParent[parentId, default: 0] += amount
            }
        } else if let majorId = transaction.majorCategory?.id {
            categoryExpenses[majorId, default: 0] += amount
        }
    }

    return ActualExpenseMaps(
        categoryExpenses: categoryExpenses,
        childExpenseByParent: childExpenseByParent,
    )
}

private func buildChildFallbackMap(from transactions: [Transaction]) -> [UUID: Set<UUID>] {
    transactions.reduce(into: [:]) { partialResult, transaction in
        guard let minorId = transaction.minorCategory?.id else { return }
        guard let parentId = transaction.majorCategory?.id ?? transaction.minorCategory?.parent?.id else {
            return
        }
        partialResult[parentId, default: []].insert(minorId)
    }
}
