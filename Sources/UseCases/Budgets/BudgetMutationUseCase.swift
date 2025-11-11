import Foundation

internal protocol BudgetMutationUseCaseProtocol {
    func addBudget(input: BudgetInput) throws
    func updateBudget(_ budget: Budget, input: BudgetInput) throws
    func deleteBudget(_ budget: Budget) throws
    func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) throws
}

internal final class DefaultBudgetMutationUseCase: BudgetMutationUseCaseProtocol {
    private let repository: BudgetRepository

    internal init(repository: BudgetRepository) {
        self.repository = repository
    }

    internal func addBudget(input: BudgetInput) throws {
        try validatePeriod(
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        let category = try resolveCategory(id: input.categoryId)
        let budget = Budget(
            amount: input.amount,
            category: category,
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        repository.insertBudget(budget)
        try repository.saveChanges()
    }

    internal func updateBudget(_ budget: Budget, input: BudgetInput) throws {
        try validatePeriod(
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        let category = try resolveCategory(id: input.categoryId)
        budget.amount = input.amount
        budget.category = category
        budget.startYear = input.startYear
        budget.startMonth = input.startMonth
        budget.endYear = input.endYear
        budget.endMonth = input.endMonth
        budget.updatedAt = Date()
        try repository.saveChanges()
    }

    internal func deleteBudget(_ budget: Budget) throws {
        repository.deleteBudget(budget)
        try repository.saveChanges()
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) throws {
        if let config = input.existingConfig {
            config.totalAmount = input.totalAmount
            config.policy = input.policy
            config.updatedAt = Date()
            try syncAllocations(config: config, drafts: input.allocations)
        } else {
            let config = AnnualBudgetConfig(
                year: input.year,
                totalAmount: input.totalAmount,
                policy: input.policy,
            )
            repository.insertAnnualBudgetConfig(config)
            try syncAllocations(config: config, drafts: input.allocations)
        }
        try repository.saveChanges()
    }
}

private extension DefaultBudgetMutationUseCase {
    func resolveCategory(id: UUID?) throws -> Category? {
        guard let id else { return nil }
        guard let category = try repository.category(id: id) else {
            throw BudgetStoreError.categoryNotFound
        }
        return category
    }

    func validatePeriod(
        startYear: Int,
        startMonth: Int,
        endYear: Int,
        endMonth: Int,
    ) throws {
        guard (2000 ... 2100).contains(startYear),
              (2000 ... 2100).contains(endYear),
              (1 ... 12).contains(startMonth),
              (1 ... 12).contains(endMonth) else {
            throw BudgetStoreError.invalidPeriod
        }

        let startIndex = startYear * 12 + startMonth
        let endIndex = endYear * 12 + endMonth
        guard startIndex <= endIndex else {
            throw BudgetStoreError.invalidPeriod
        }
    }

    func syncAllocations(
        config: AnnualBudgetConfig,
        drafts: [AnnualAllocationDraft],
    ) throws {
        let uniqueCategoryIds = Set(drafts.map(\.categoryId))
        guard uniqueCategoryIds.count == drafts.count else {
            throw BudgetStoreError.duplicateAnnualAllocationCategory
        }

        var existingAllocations: [UUID: AnnualBudgetAllocation] = [:]
        for allocation in config.allocations {
            existingAllocations[allocation.category.id] = allocation
        }

        var seenCategoryIds: Set<UUID> = []
        let now = Date()

        for draft in drafts {
            guard let category = try resolveCategory(id: draft.categoryId) else {
                throw BudgetStoreError.categoryNotFound
            }

            if !category.allowsAnnualBudget {
                category.allowsAnnualBudget = true
                category.updatedAt = now
            }

            seenCategoryIds.insert(category.id)

            if let allocation = existingAllocations[category.id] {
                allocation.amount = draft.amount
                allocation.policyOverride = draft.policyOverride
                allocation.updatedAt = now
            } else {
                let allocation = AnnualBudgetAllocation(
                    amount: draft.amount,
                    category: category,
                    policyOverride: draft.policyOverride,
                )
                allocation.updatedAt = now
                config.allocations.append(allocation)
            }
        }

        let allocationsToRemove = config.allocations.filter { !seenCategoryIds.contains($0.category.id) }
        for allocation in allocationsToRemove {
            if let index = config.allocations.firstIndex(where: { $0.id == allocation.id }) {
                config.allocations.remove(at: index)
            }
            repository.deleteAllocation(allocation)
        }
    }
}
