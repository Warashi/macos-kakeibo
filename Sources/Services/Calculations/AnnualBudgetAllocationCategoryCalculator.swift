import Foundation

internal struct MonthlyCategoryAllocationRequest {
    internal let params: AllocationCalculationParams
    internal let year: Int
    internal let month: Int
    internal let policy: AnnualBudgetPolicy
    internal let policyOverrides: [UUID: AnnualBudgetPolicy]
}

/// 月次カテゴリ別の充当計算を担当
internal struct AnnualBudgetAllocationCategoryCalculator: Sendable {
    internal func calculateCategoryAllocations(
        request: MonthlyCategoryAllocationRequest,
        categories: [Category],
    ) -> [CategoryAllocation] {
        let filteredTransactions = filterTransactions(
            transactions: request.params.transactions,
            year: request.year,
            month: request.month,
            filter: request.params.filter,
        )

        let expenseMaps = makeActualExpenseMaps(from: filteredTransactions, categories: categories)
        let actualExpenseMap = expenseMaps.categoryExpenses
        let childExpenseMap = expenseMaps.childExpenseByParent
        let childFallbackMap = buildChildFallbackMap(from: filteredTransactions, categories: categories)
        let monthlyBudgets = request.params.budgets.filter { $0.contains(year: request.year, month: request.month) }
        let allocationAmounts = allocationAmountMap(from: request.params.annualBudgetConfig)
        let policyContext = PolicyContext(
            overrides: request.policyOverrides,
            defaultPolicy: request.policy,
            allocationAmounts: allocationAmounts,
            allocatedCategoryIds: Set(allocationAmounts.keys),
        )

        if request.policy == .disabled, policyContext.overrides.isEmpty {
            return []
        }

        let computationContext = AllocationComputationContext(
            actualExpenseMap: actualExpenseMap,
            childExpenseMap: childExpenseMap,
            policyContext: policyContext,
            childFallbackMap: childFallbackMap,
        )

        var allocations: [CategoryAllocation] = []
        var processedCategoryIds: Set<UUID> = []

        allocations.append(
            contentsOf: calculateAllocationsForMonthlyBudgets(
                budgets: monthlyBudgets,
                categories: categories,
                context: computationContext,
                processedCategoryIds: &processedCategoryIds,
            ),
        )

        allocations.append(
            contentsOf: calculateAllocationsForFullCoverage(
                config: request.params.annualBudgetConfig,
                categories: categories,
                context: computationContext,
                processedCategoryIds: &processedCategoryIds,
            ),
        )

        allocations.append(
            contentsOf: calculateAllocationsForUnbudgetedCategories(
                config: request.params.annualBudgetConfig,
                categories: categories,
                context: computationContext,
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

    private struct AllocationComputationContext {
        let actualExpenseMap: [UUID: Decimal]
        let childExpenseMap: [UUID: Decimal]
        let policyContext: PolicyContext
        let childFallbackMap: [UUID: Set<UUID>]
    }

    private func calculateAllocationsForMonthlyBudgets(
        budgets: [Budget],
        categories: [Category],
        context: AllocationComputationContext,
        processedCategoryIds: inout Set<UUID>,
    ) -> [CategoryAllocation] {
        var allocations: [CategoryAllocation] = []
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        for budget in budgets {
            guard let categoryId = budget.categoryId,
                  let category = categoryMap[categoryId] else { continue }

            let isEligible = category.allowsAnnualBudget || context.policyContext.allocationAmounts[categoryId] != nil
            guard isEligible else { continue }
            let annualBudgetAmount = context.policyContext.allocationAmounts[categoryId] ?? 0
            let effectivePolicy = context.policyContext.overrides[categoryId] ?? context.policyContext.defaultPolicy
            guard effectivePolicy != .disabled else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                categories: categories,
                context: context,
            )

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: budget.amount,
                policy: effectivePolicy,
            )

            let categoryName = buildCategoryName(category: category, categories: categories)

            allocations.append(
                CategoryAllocation(
                    categoryId: categoryId,
                    categoryName: categoryName,
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
        categories: [Category],
        context: AllocationComputationContext,
        processedCategoryIds: inout Set<UUID>,
    ) -> [CategoryAllocation] {
        var allocations: [CategoryAllocation] = []
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        for allocation in config.allocations {
            let categoryId = allocation.categoryId
            guard let category = categoryMap[categoryId] else { continue }
            guard !processedCategoryIds.contains(categoryId) else { continue }

            let effectivePolicy = context.policyContext.overrides[categoryId] ?? context.policyContext.defaultPolicy
            guard effectivePolicy != .disabled else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                categories: categories,
                context: context,
            )
            guard actualAmount > 0 else { continue }

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: 0,
                policy: effectivePolicy,
            )

            let categoryName = buildCategoryName(category: category, categories: categories)

            allocations.append(
                CategoryAllocation(
                    categoryId: categoryId,
                    categoryName: categoryName,
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
        categories: [Category],
        context: AllocationComputationContext,
        processedCategoryIds: inout Set<UUID>,
    ) -> [CategoryAllocation] {
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let fullCoverageAllocations = config.allocations
            .filter { $0.policyOverride == .fullCoverage }
            .compactMap { allocation -> (AnnualBudgetAllocation, Category)? in
                guard let category = categoryMap[allocation.categoryId] else { return nil }
                return (allocation, category)
            }
            .sorted { lhs, rhs in
                let lhsName = buildCategoryName(category: lhs.1, categories: categories)
                let rhsName = buildCategoryName(category: rhs.1, categories: categories)
                return lhsName < rhsName
            }

        var allocations: [CategoryAllocation] = []

        for (allocation, category) in fullCoverageAllocations {
            let categoryId = allocation.categoryId
            guard !processedCategoryIds.contains(categoryId) else { continue }
            let effectivePolicy = context.policyContext.overrides[categoryId] ?? context.policyContext.defaultPolicy
            guard effectivePolicy == .fullCoverage else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                categories: categories,
                context: context,
            )
            guard actualAmount > 0 else { continue }

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: 0,
                policy: .fullCoverage,
            )

            let categoryName = buildCategoryName(category: category, categories: categories)

            allocations.append(
                CategoryAllocation(
                    categoryId: categoryId,
                    categoryName: categoryName,
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
        categories: [Category],
        context: AllocationComputationContext,
    ) -> Decimal {
        let categoryId = category.id
        if category.isMajor {
            let childCategories = categories.filter { $0.parentId == categoryId }
            let childCategoryIds: Set<UUID> = if childCategories.isEmpty,
                                                 let fallbackChildren = context.childFallbackMap[categoryId] {
                fallbackChildren
            } else {
                Set(childCategories.map(\.id))
            }
            var total = context.actualExpenseMap[categoryId] ?? 0

            for childId in childCategoryIds where !context.policyContext.allocatedCategoryIds.contains(childId) {
                total += context.actualExpenseMap[childId] ?? 0
            }

            if childCategoryIds.isEmpty {
                total += context.childExpenseMap[categoryId] ?? 0
            }

            return total
        }
        return context.actualExpenseMap[categoryId] ?? 0
    }

    private func allocationAmountMap(from config: AnnualBudgetConfig) -> [UUID: Decimal] {
        config.allocations.reduce(into: [:]) { partialResult, allocation in
            partialResult[allocation.categoryId] = allocation.amount
        }
    }

    private func buildCategoryName(category: Category, categories: [Category]) -> String {
        if let parentId = category.parentId,
           let parent = categories.first(where: { $0.id == parentId }) {
            return "\(parent.name) > \(category.name)"
        }
        return category.name
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

private struct AllocationAmounts {
    let allocatable: Decimal
    let excess: Decimal
    let remainingAfterAllocation: Decimal
}

private struct ActualExpenseMaps {
    let categoryExpenses: [UUID: Decimal]
    let childExpenseByParent: [UUID: Decimal]
}

// MARK: - Filtering Helpers

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
        guard transaction.financialInstitutionId == institutionId else {
            return false
        }
    }

    if let categoryId = filter.categoryId {
        let majorMatches = transaction.majorCategoryId == categoryId
        let minorMatches = transaction.minorCategoryId == categoryId
        guard majorMatches || minorMatches else {
            return false
        }
    }

    return true
}

private func makeActualExpenseMaps(
    from transactions: [Transaction],
    categories: [Category],
) -> ActualExpenseMaps {
    var categoryExpenses: [UUID: Decimal] = [:]
    var childExpenseByParent: [UUID: Decimal] = [:]
    let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

    for transaction in transactions where transaction.isExpense {
        let amount = abs(transaction.amount)

        if let minorId = transaction.minorCategoryId {
            categoryExpenses[minorId, default: 0] += amount
            let minor = categoryMap[minorId]
            let parentId = transaction.majorCategoryId ?? minor?.parentId
            if let parentId {
                childExpenseByParent[parentId, default: 0] += amount
            }
        } else if let majorId = transaction.majorCategoryId {
            categoryExpenses[majorId, default: 0] += amount
        }
    }

    return ActualExpenseMaps(
        categoryExpenses: categoryExpenses,
        childExpenseByParent: childExpenseByParent,
    )
}

private func buildChildFallbackMap(
    from transactions: [Transaction],
    categories: [Category],
) -> [UUID: Set<UUID>] {
    let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

    return transactions.reduce(into: [:]) { partialResult, transaction in
        guard let minorId = transaction.minorCategoryId else { return }
        let minor = categoryMap[minorId]
        guard let parentId = transaction.majorCategoryId ?? minor?.parentId else {
            return
        }
        partialResult[parentId, default: []].insert(minorId)
    }
}
