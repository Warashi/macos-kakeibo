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

    /// 予算超過額（全額年次枠扱いのカテゴリでは実績額）
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
        let filteredTransactions = filterTransactions(
            transactions: params.transactions,
            year: year,
            month: month,
            filter: params.filter,
        )

        let actualExpenseMap = makeActualExpenseMap(from: filteredTransactions)
        let monthlyBudgets = params.budgets.filter { $0.contains(year: year, month: month) }
        let policyContext = PolicyContext(
            overrides: policyOverrideMap(from: params.annualBudgetConfig),
            defaultPolicy: policy,
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
                policyContext: policyContext,
                processedCategoryIds: &processedCategoryIds,
            ),
        )

        allocations.append(
            contentsOf: calculateAllocationsForFullCoverage(
                config: params.annualBudgetConfig,
                actualExpenseMap: actualExpenseMap,
                processedCategoryIds: &processedCategoryIds,
            ),
        )

        return allocations
    }

    private struct PolicyContext {
        let overrides: [UUID: AnnualBudgetPolicy]
        let defaultPolicy: AnnualBudgetPolicy
    }

    private func calculateAllocationsForMonthlyBudgets(
        budgets: [Budget],
        actualExpenseMap: [UUID: Decimal],
        policyContext: PolicyContext,
        processedCategoryIds: inout Set<UUID>,
    ) -> [CategoryAllocation] {
        var allocations: [CategoryAllocation] = []

        for budget in budgets {
            guard let category = budget.category else { continue }
            guard category.allowsAnnualBudget else { continue }

            let categoryId = category.id
            let effectivePolicy = policyContext.overrides[categoryId] ?? policyContext.defaultPolicy
            guard effectivePolicy != .disabled else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                from: actualExpenseMap,
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

    private func calculateAllocationsForFullCoverage(
        config: AnnualBudgetConfig,
        actualExpenseMap: [UUID: Decimal],
        processedCategoryIds: inout Set<UUID>,
    ) -> [CategoryAllocation] {
        let fullCoverageAllocations = config.allocations
            .filter { $0.policyOverride == .fullCoverage }
            .sorted { lhs, rhs in lhs.category.fullName < rhs.category.fullName }

        var allocations: [CategoryAllocation] = []

        for allocation in fullCoverageAllocations {
            let category = allocation.category
            let categoryId = category.id
            guard category.allowsAnnualBudget else { continue }
            guard !processedCategoryIds.contains(categoryId) else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                from: actualExpenseMap,
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
    ) -> Decimal {
        let categoryId = category.id
        if category.isMajor {
            // 大項目の場合：大項目自身と全ての子カテゴリの実績を合計
            let childCategoryIds = Set(category.children.map(\.id))
            return actualExpenseMap
                .filter { id, _ in
                    id == categoryId || childCategoryIds.contains(id)
                }
                .reduce(Decimal.zero) { $0 + $1.value }
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

    private func calculateAllocationAmounts(
        actualAmount: Decimal,
        budgetAmount: Decimal,
        policy: AnnualBudgetPolicy,
    ) -> (allocatable: Decimal, excess: Decimal, remainingAfterAllocation: Decimal) {
        switch policy {
        case .automatic:
            let excess = max(0, actualAmount - budgetAmount)
            return (
                allocatable: excess,
                excess: excess,
                remainingAfterAllocation: 0,
            )
        case .manual:
            let excess = max(0, actualAmount - budgetAmount)
            return (
                allocatable: 0,
                excess: excess,
                remainingAfterAllocation: excess,
            )
        case .disabled:
            return (
                allocatable: 0,
                excess: 0,
                remainingAfterAllocation: 0,
            )
        case .fullCoverage:
            return (
                allocatable: actualAmount,
                excess: actualAmount,
                remainingAfterAllocation: 0,
            )
        }
    }

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

    private func makeActualExpenseMap(from transactions: [Transaction]) -> [UUID: Decimal] {
        transactions.reduce(into: [:]) { partialResult, transaction in
            guard transaction.isExpense else { return }
            let amount = abs(transaction.amount)

            if let majorId = transaction.majorCategory?.id ?? transaction.minorCategory?.parent?.id {
                partialResult[majorId, default: 0] += amount
            }

            if let minorId = transaction.minorCategory?.id {
                partialResult[minorId, default: 0] += amount
            }
        }
    }
}
