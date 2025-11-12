import Foundation

internal protocol AnnualBudgetUseCaseProtocol {
    func annualBudgetUsage(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> AnnualBudgetUsage?

    func annualOverallEntry(
        snapshot: BudgetSnapshot,
        year: Int,
    ) -> AnnualBudgetEntry?

    func annualCategoryEntries(
        snapshot: BudgetSnapshot,
        year: Int,
    ) -> [AnnualBudgetEntry]
}

internal final class DefaultAnnualBudgetUseCase: AnnualBudgetUseCaseProtocol {
    private let allocator: AnnualBudgetAllocator
    private let progressCalculator: AnnualBudgetProgressCalculator

    internal init(
        allocator: AnnualBudgetAllocator = AnnualBudgetAllocator(),
        progressCalculator: AnnualBudgetProgressCalculator = AnnualBudgetProgressCalculator(),
    ) {
        self.allocator = allocator
        self.progressCalculator = progressCalculator
    }

    internal func annualBudgetUsage(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> AnnualBudgetUsage? {
        guard let config = snapshot.annualBudgetConfig else { return nil }
        let params = AllocationCalculationParams(
            transactions: snapshot.transactions,
            budgets: snapshot.budgets,
            annualBudgetConfig: config,
            filter: .default,
        )
        return allocator.calculateAnnualBudgetUsage(params: params, upToMonth: month)
    }

    internal func annualOverallEntry(
        snapshot: BudgetSnapshot,
        year: Int,
    ) -> AnnualBudgetEntry? {
        annualProgressResult(snapshot: snapshot, year: year).overallEntry
    }

    internal func annualCategoryEntries(
        snapshot: BudgetSnapshot,
        year: Int,
    ) -> [AnnualBudgetEntry] {
        annualProgressResult(snapshot: snapshot, year: year).categoryEntries
    }
}

private extension DefaultAnnualBudgetUseCase {
    func annualProgressResult(snapshot: BudgetSnapshot, year: Int) -> AnnualBudgetProgressResult {
        progressCalculator.calculate(
            budgets: snapshot.budgets,
            transactions: snapshot.transactions,
            categories: snapshot.categories,
            year: year,
            filter: .default,
            excludedCategoryIds: snapshot.annualBudgetConfig?.fullCoverageCategoryIDs(
                includingChildrenFrom: snapshot.categories,
            ) ?? [],
        )
    }
}
