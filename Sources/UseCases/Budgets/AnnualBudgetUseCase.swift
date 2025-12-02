import Foundation

internal protocol AnnualBudgetUseCaseProtocol: Sendable {
    func annualBudgetUsage(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> AnnualBudgetUsage?

    func annualOverallEntry(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int?,
    ) -> AnnualBudgetEntry?

    func annualCategoryEntries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int?,
    ) -> [AnnualBudgetEntry]
}

internal final class DefaultAnnualBudgetUseCase: AnnualBudgetUseCaseProtocol {
    private let allocator: AnnualBudgetAllocator
    private let progressCalculator: AnnualBudgetProgressCalculator
    private let monthPeriodCalculator: MonthPeriodCalculator
    private let currentDateProvider: @Sendable () -> Date

    internal init(
        allocator: AnnualBudgetAllocator = AnnualBudgetAllocator(),
        progressCalculator: AnnualBudgetProgressCalculator = AnnualBudgetProgressCalculator(),
        monthPeriodCalculator: MonthPeriodCalculator = MonthPeriodCalculatorFactory.make(),
        currentDateProvider: @escaping @Sendable () -> Date = Date.init,
    ) {
        self.allocator = allocator
        self.progressCalculator = progressCalculator
        self.monthPeriodCalculator = monthPeriodCalculator
        self.currentDateProvider = currentDateProvider
    }

    internal func annualBudgetUsage(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> AnnualBudgetUsage? {
        guard let config = snapshot.annualBudgetConfig else { return nil }
        let upToMonth = resolveUpToMonth(for: year, requestedMonth: month)
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
            upToMonth: upToMonth,
        )
    }

    internal func annualOverallEntry(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int?,
    ) -> AnnualBudgetEntry? {
        let upToMonth = resolveUpToMonth(for: year, requestedMonth: month)
        return annualProgressResult(snapshot: snapshot, year: year, month: upToMonth).overallEntry
    }

    internal func annualCategoryEntries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int?,
    ) -> [AnnualBudgetEntry] {
        let upToMonth = resolveUpToMonth(for: year, requestedMonth: month)
        return annualProgressResult(snapshot: snapshot, year: year, month: upToMonth).categoryEntries
    }
}

private extension DefaultAnnualBudgetUseCase {
    func resolveUpToMonth(for year: Int, requestedMonth: Int?) -> Int? {
        if let requestedMonth {
            let clampedRequested = max(1, min(12, requestedMonth))
            guard let resolved = resolveUpToMonth(for: year) else {
                return clampedRequested
            }
            return min(clampedRequested, resolved)
        }
        return resolveUpToMonth(for: year)
    }

    func resolveUpToMonth(for year: Int) -> Int? {
        let now = currentDateProvider()
        guard monthPeriodCalculator.monthContaining(now, in: year) != nil else {
            return nil
        }
        return monthPeriodCalculator.monthsElapsed(in: year, until: now)
    }

    func annualProgressResult(snapshot: BudgetSnapshot, year: Int, month: Int?) -> AnnualBudgetProgressResult {
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
            upToMonth: month,
        )
    }

    /// 定期支払いとリンクされた取引を除外するフィルタを作成
    func makeFilter(from snapshot: BudgetSnapshot) -> AggregationFilter {
        let excludedTransactionIds = Set(
            snapshot.recurringPaymentOccurrences
                .compactMap(\.transactionId),
        )
        return AggregationFilter(
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            financialInstitutionId: nil,
            categoryId: nil,
            excludedTransactionIds: excludedTransactionIds,
        )
    }
}
