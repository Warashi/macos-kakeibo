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
        let filter = makeFilter(from: snapshot)
        let params = AllocationCalculationParams(
            transactions: snapshot.transactions,
            budgets: snapshot.budgets,
            annualBudgetConfig: config,
            filter: filter,
        )
        return allocator.calculateAnnualBudgetUsage(
            params: params,
            categories: snapshot.categories,
            upToMonth: month,
        )
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
        let filter = makeFilter(from: snapshot)
        return progressCalculator.calculate(
            budgets: snapshot.budgets,
            transactions: snapshot.transactions,
            categories: snapshot.categories,
            year: year,
            filter: filter,
            excludedCategoryIds: snapshot.annualBudgetConfig?.fullCoverageCategoryIDs(
                includingChildrenFrom: snapshot.categories,
            ) ?? [],
        )
    }

    /// 定期支払いとリンクされた取引を除外するフィルタを作成
    func makeFilter(from snapshot: BudgetSnapshot) -> AggregationFilter {
        let excludedTransactionIds = Set(
            snapshot.recurringPaymentOccurrences
                .compactMap(\.transactionId)
        )
        return AggregationFilter(
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            financialInstitutionId: nil,
            categoryId: nil,
            excludedTransactionIds: excludedTransactionIds
        )
    }
}
