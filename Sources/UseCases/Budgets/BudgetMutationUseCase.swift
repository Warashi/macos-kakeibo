import Foundation

@DatabaseActor
internal protocol BudgetMutationUseCaseProtocol: Sendable {
    func addBudget(input: BudgetInput) async throws
    func updateBudget(_ budget: BudgetDTO, input: BudgetInput) async throws
    func deleteBudget(_ budget: BudgetDTO) async throws
    func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) async throws
}

@DatabaseActor
internal final class DefaultBudgetMutationUseCase: BudgetMutationUseCaseProtocol {
    private let repository: BudgetRepository

    internal init(repository: BudgetRepository) {
        self.repository = repository
    }

    internal func addBudget(input: BudgetInput) async throws {
        try validatePeriod(
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        try validateCategoryExists(id: input.categoryId)
        try repository.addBudget(input)
        try repository.saveChanges()
    }

    internal func updateBudget(_ budget: BudgetDTO, input: BudgetInput) async throws {
        try validatePeriod(
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        try validateCategoryExists(id: input.categoryId)
        try repository.updateBudget(
            input: BudgetUpdateInput(
                id: budget.id,
                input: input,
            ),
        )
        try repository.saveChanges()
    }

    internal func deleteBudget(_ budget: BudgetDTO) async throws {
        try repository.deleteBudget(id: budget.id)
        try repository.saveChanges()
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) async throws {
        try validateAllocationDrafts(input.allocations)
        try validateCategoriesExist(in: input.allocations)
        try repository.upsertAnnualBudgetConfig(input)
        try repository.saveChanges()
    }
}

private extension DefaultBudgetMutationUseCase {
    func validateCategoryExists(id: UUID?) throws {
        guard let id else { return }
        guard try repository.category(id: id) != nil else {
            throw BudgetStoreError.categoryNotFound
        }
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

    func validateAllocationDrafts(_ drafts: [AnnualAllocationDraft]) throws {
        let uniqueCategoryIds = Set(drafts.map(\.categoryId))
        guard uniqueCategoryIds.count == drafts.count else {
            throw BudgetStoreError.duplicateAnnualAllocationCategory
        }
    }

    func validateCategoriesExist(in drafts: [AnnualAllocationDraft]) throws {
        for draft in drafts {
            guard try repository.category(id: draft.categoryId) != nil else {
                throw BudgetStoreError.categoryNotFound
            }
        }
    }
}
