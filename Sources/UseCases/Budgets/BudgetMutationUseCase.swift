import Foundation

internal protocol BudgetMutationUseCaseProtocol: Sendable {
    func addBudget(input: BudgetInput) async throws
    func updateBudget(_ budget: Budget, input: BudgetInput) async throws
    func deleteBudget(_ budget: Budget) async throws
    func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) async throws
}

internal struct DefaultBudgetMutationUseCase: BudgetMutationUseCaseProtocol {
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
        try await validateCategoryExists(id: input.categoryId)
        try await repository.addBudget(input)
        try await repository.saveChanges()
    }

    internal func updateBudget(_ budget: Budget, input: BudgetInput) async throws {
        try validatePeriod(
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        try await validateCategoryExists(id: input.categoryId)
        try await repository.updateBudget(
            input: BudgetUpdateInput(
                id: budget.id,
                input: input,
            ),
        )
        try await repository.saveChanges()
    }

    internal func deleteBudget(_ budget: Budget) async throws {
        try await repository.deleteBudget(id: budget.id)
        try await repository.saveChanges()
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) async throws {
        try validateAllocationDrafts(input.allocations)
        try await validateCategoriesExist(in: input.allocations)
        try await repository.upsertAnnualBudgetConfig(input)
        try await repository.saveChanges()
    }
}

private extension DefaultBudgetMutationUseCase {
    func validateCategoryExists(id: UUID?) async throws {
        guard let id else { return }
        guard try await repository.category(id: id) != nil else {
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

    func validateCategoriesExist(in drafts: [AnnualAllocationDraft]) async throws {
        for draft in drafts {
            guard try await repository.category(id: draft.categoryId) != nil else {
                throw BudgetStoreError.categoryNotFound
            }
        }
    }
}
