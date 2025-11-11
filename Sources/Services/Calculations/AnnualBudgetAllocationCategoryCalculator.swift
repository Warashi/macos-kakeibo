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
        request: MonthlyCategoryAllocationRequest
    ) -> [CategoryAllocation] {
        let filteredTransactions = filterTransactions(
            transactions: request.params.transactions,
            year: request.year,
            month: request.month,
            filter: request.params.filter
        )

        let expenseMaps = makeActualExpenseMaps(from: filteredTransactions)
        let actualExpenseMap = expenseMaps.categoryExpenses
        let childExpenseMap = expenseMaps.childExpenseByParent
        let childFallbackMap = buildChildFallbackMap(from: filteredTransactions)
        let monthlyBudgets = request.params.budgets.filter { $0.contains(year: request.year, month: request.month) }
        let allocationAmounts = allocationAmountMap(from: request.params.annualBudgetConfig)
        let policyContext = PolicyContext(
            overrides: request.policyOverrides,
            defaultPolicy: request.policy,
            allocationAmounts: allocationAmounts,
            allocatedCategoryIds: Set(allocationAmounts.keys)
        )

        if request.policy == .disabled, policyContext.overrides.isEmpty {
            return []
        }

        let computationContext = AllocationComputationContext(
            actualExpenseMap: actualExpenseMap,
            childExpenseMap: childExpenseMap,
            policyContext: policyContext,
            childFallbackMap: childFallbackMap
        )

        var allocations: [CategoryAllocation] = []
        var processedCategoryIds: Set<UUID> = []

        allocations.append(
            contentsOf: calculateAllocationsForMonthlyBudgets(
                budgets: monthlyBudgets,
                context: computationContext,
                processedCategoryIds: &processedCategoryIds
            )
        )

        allocations.append(
            contentsOf: calculateAllocationsForFullCoverage(
                config: request.params.annualBudgetConfig,
                context: computationContext,
                processedCategoryIds: &processedCategoryIds
            )
        )

        allocations.append(
            contentsOf: calculateAllocationsForUnbudgetedCategories(
                config: request.params.annualBudgetConfig,
                context: computationContext,
                processedCategoryIds: &processedCategoryIds
            )
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
        context: AllocationComputationContext,
        processedCategoryIds: inout Set<UUID>
    ) -> [CategoryAllocation] {
        var allocations: [CategoryAllocation] = []

        for budget in budgets {
            guard let category = budget.category else { continue }

            let categoryId = category.id
            let isEligible = category.allowsAnnualBudget || context.policyContext.allocationAmounts[categoryId] != nil
            guard isEligible else { continue }
            let annualBudgetAmount = context.policyContext.allocationAmounts[categoryId] ?? 0
            let effectivePolicy = context.policyContext.overrides[categoryId] ?? context.policyContext.defaultPolicy
            guard effectivePolicy != .disabled else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                context: context
            )

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: budget.amount,
                policy: effectivePolicy
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
                    remainingAfterAllocation: amounts.remainingAfterAllocation
                )
            )

            processedCategoryIds.insert(categoryId)
        }

        return allocations
    }
    private func calculateAllocationsForUnbudgetedCategories(
        config: AnnualBudgetConfig,
        context: AllocationComputationContext,
        processedCategoryIds: inout Set<UUID>
    ) -> [CategoryAllocation] {
        var allocations: [CategoryAllocation] = []

        for allocation in config.allocations {
            let category = allocation.category
            let categoryId = category.id
            guard !processedCategoryIds.contains(categoryId) else { continue }

            let effectivePolicy = context.policyContext.overrides[categoryId] ?? context.policyContext.defaultPolicy
            guard effectivePolicy != .disabled else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                context: context
            )
            guard actualAmount > 0 else { continue }

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: 0,
                policy: effectivePolicy
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
                    remainingAfterAllocation: amounts.remainingAfterAllocation
                )
            )

            processedCategoryIds.insert(categoryId)
        }

        return allocations
    }
    private func calculateAllocationsForFullCoverage(
        config: AnnualBudgetConfig,
        context: AllocationComputationContext,
        processedCategoryIds: inout Set<UUID>
    ) -> [CategoryAllocation] {
        let fullCoverageAllocations = config.allocations
            .filter { $0.policyOverride == .fullCoverage }
            .sorted { lhs, rhs in lhs.category.fullName < rhs.category.fullName }

        var allocations: [CategoryAllocation] = []

        for allocation in fullCoverageAllocations {
            let category = allocation.category
            let categoryId = category.id
            guard !processedCategoryIds.contains(categoryId) else { continue }
            let effectivePolicy = context.policyContext.overrides[categoryId] ?? context.policyContext.defaultPolicy
            guard effectivePolicy == .fullCoverage else { continue }

            let actualAmount = calculateActualAmount(
                for: category,
                context: context
            )
            guard actualAmount > 0 else { continue }

            let amounts = calculateAllocationAmounts(
                actualAmount: actualAmount,
                budgetAmount: 0,
                policy: .fullCoverage
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
                    remainingAfterAllocation: amounts.remainingAfterAllocation
                )
            )

            processedCategoryIds.insert(categoryId)
        }

        return allocations
    }
    private func calculateActualAmount(
        for category: Category,
        context: AllocationComputationContext
    ) -> Decimal {
        let categoryId = category.id
        if category.isMajor {
            let childCategoryIds: Set<UUID> = if category.children.isEmpty,
                                                 let fallbackChildren = context.childFallbackMap[categoryId] {
                fallbackChildren
            } else {
                Set(category.children.map(\.id))
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
            partialResult[allocation.category.id] = allocation.amount
        }
    }

    private func calculateAllocationAmounts(
        actualAmount: Decimal,
        budgetAmount: Decimal,
        policy: AnnualBudgetPolicy
    ) -> AllocationAmounts {
        switch policy {
        case .automatic:
            let excess = max(0, actualAmount - budgetAmount)
            return AllocationAmounts(
                allocatable: excess,
                excess: excess,
                remainingAfterAllocation: 0
            )
        case .manual:
            let excess = max(0, actualAmount - budgetAmount)
            return AllocationAmounts(
                allocatable: 0,
                excess: excess,
                remainingAfterAllocation: excess
            )
        case .disabled:
            return AllocationAmounts(
                allocatable: 0,
                excess: 0,
                remainingAfterAllocation: 0
            )
        case .fullCoverage:
            return AllocationAmounts(
                allocatable: actualAmount,
                excess: actualAmount,
                remainingAfterAllocation: 0
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
    filter: AggregationFilter
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
    filter: AggregationFilter
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
        childExpenseByParent: childExpenseByParent
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
