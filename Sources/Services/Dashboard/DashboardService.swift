import Foundation

/// Dashboard calculation service
///
/// Encapsulates dashboard calculation logic, keeping it separate from UI state management.
/// Runs on MainActor due to SwiftData model access requirements.
@MainActor
internal final class DashboardService {
    // MARK: - Dependencies

    private let aggregator: TransactionAggregator
    private let budgetCalculator: BudgetCalculator
    private let annualBudgetAllocator: AnnualBudgetAllocator
    private let annualBudgetProgressCalculator: AnnualBudgetProgressCalculator

    // MARK: - Initialization

    internal init() {
        self.aggregator = TransactionAggregator()
        self.budgetCalculator = BudgetCalculator()
        self.annualBudgetAllocator = AnnualBudgetAllocator()
        self.annualBudgetProgressCalculator = AnnualBudgetProgressCalculator()
    }

    // MARK: - Dashboard Calculation

    /// Calculate dashboard data
    /// - Parameters:
    ///   - input: Input data (transactions, budgets, etc.)
    ///   - year: Target year
    ///   - month: Target month
    ///   - displayMode: Display mode (monthly/annual)
    /// - Returns: Dashboard calculation result
    internal func calculate(
        input: DashboardInput,
        year: Int,
        month: Int,
        displayMode: DashboardStore.DisplayMode,
    ) -> DashboardResult {
        let excludedCategoryIds = input.config?.fullCoverageCategoryIDs(
            includingChildrenFrom: input.categories,
        ) ?? []

        let monthlySummary = aggregator.aggregateMonthly(
            transactions: input.monthlyTransactions,
            year: year,
            month: month,
            filter: .default,
        )

        let annualSummary = aggregator.aggregateAnnually(
            transactions: input.annualTransactions,
            year: year,
            filter: .default,
        )

        let monthlyBudgetCalculation = budgetCalculator.calculateMonthlyBudget(
            transactions: input.monthlyTransactions,
            budgets: input.budgets,
            year: year,
            month: month,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
        )

        let (annualBudgetUsage, monthlyAllocation) = calculateAnnualBudgetAllocation(
            input: input,
            year: year,
            month: month,
        )

        let categoryHighlights = calculateCategoryHighlights(
            monthlySummary: monthlySummary,
            annualSummary: annualSummary,
            displayMode: displayMode,
        )

        let (progressCalculation, categoryEntries) = calculateAnnualBudgetProgress(
            input: input,
            year: year,
            excludedCategoryIds: excludedCategoryIds,
        )

        return DashboardResult(
            monthlySummary: monthlySummary,
            annualSummary: annualSummary,
            monthlyBudgetCalculation: monthlyBudgetCalculation,
            annualBudgetUsage: annualBudgetUsage,
            monthlyAllocation: monthlyAllocation,
            categoryHighlights: categoryHighlights,
            annualBudgetProgressCalculation: progressCalculation,
            annualBudgetCategoryEntries: categoryEntries,
        )
    }

    // MARK: - Private Helpers

    private func calculateAnnualBudgetAllocation(
        input: DashboardInput,
        year: Int,
        month: Int,
    ) -> (AnnualBudgetUsage?, MonthlyAllocation?) {
        guard let config = input.config else {
            return (nil, nil)
        }

        let params = AllocationCalculationParams(
            transactions: input.annualTransactions,
            budgets: input.budgets,
            annualBudgetConfig: config,
            filter: .default,
        )

        let usage = annualBudgetAllocator.calculateAnnualBudgetUsage(
            params: params,
            upToMonth: month,
        )

        let allocation = annualBudgetAllocator.calculateMonthlyAllocation(
            params: params,
            year: year,
            month: month,
        )

        return (usage, allocation)
    }

    private func calculateCategoryHighlights(
        monthlySummary: MonthlySummary,
        annualSummary: AnnualSummary,
        displayMode: DashboardStore.DisplayMode,
    ) -> [CategorySummary] {
        let summaries = displayMode == .monthly
            ? monthlySummary.categorySummaries
            : annualSummary.categorySummaries
        return Array(summaries.prefix(10))
    }

    private func calculateAnnualBudgetProgress(
        input: DashboardInput,
        year: Int,
        excludedCategoryIds: Set<UUID>,
    ) -> (BudgetCalculation?, [AnnualBudgetEntry]) {
        let progressResult = annualBudgetProgressCalculator.calculate(
            budgets: input.budgets,
            transactions: input.annualTransactions,
            year: year,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
        )

        if progressResult.overallEntry == nil, progressResult.categoryEntries.isEmpty {
            return (nil, [])
        } else {
            return (progressResult.aggregateCalculation, progressResult.categoryEntries)
        }
    }
}

// MARK: - Input/Output Types

/// Dashboard calculation input
internal struct DashboardInput {
    internal let monthlyTransactions: [Transaction]
    internal let annualTransactions: [Transaction]
    internal let budgets: [Budget]
    internal let categories: [Category]
    internal let config: AnnualBudgetConfig?
}

/// Dashboard calculation result
internal struct DashboardResult {
    internal let monthlySummary: MonthlySummary
    internal let annualSummary: AnnualSummary
    internal let monthlyBudgetCalculation: MonthlyBudgetCalculation
    internal let annualBudgetUsage: AnnualBudgetUsage?
    internal let monthlyAllocation: MonthlyAllocation?
    internal let categoryHighlights: [CategorySummary]
    internal let annualBudgetProgressCalculation: BudgetCalculation?
    internal let annualBudgetCategoryEntries: [AnnualBudgetEntry]
}
