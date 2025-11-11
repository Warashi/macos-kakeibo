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
        // Excluded category IDs
        let excludedCategoryIds = input.config?.fullCoverageCategoryIDs(
            includingChildrenFrom: input.categories,
        ) ?? []

        // Monthly summary
        let monthlySummary = aggregator.aggregateMonthly(
            transactions: input.monthlyTransactions,
            year: year,
            month: month,
            filter: .default,
        )

        // Annual summary
        let annualSummary = aggregator.aggregateAnnually(
            transactions: input.annualTransactions,
            year: year,
            filter: .default,
        )

        // Monthly budget calculation
        let monthlyBudgetCalculation = budgetCalculator.calculateMonthlyBudget(
            transactions: input.monthlyTransactions,
            budgets: input.budgets,
            year: year,
            month: month,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
        )

        // Annual budget usage
        var annualBudgetUsage: AnnualBudgetUsage?
        var monthlyAllocation: MonthlyAllocation?
        if let config = input.config {
            let params = AllocationCalculationParams(
                transactions: input.annualTransactions,
                budgets: input.budgets,
                annualBudgetConfig: config,
                filter: .default,
            )
            annualBudgetUsage = annualBudgetAllocator.calculateAnnualBudgetUsage(
                params: params,
                upToMonth: month,
            )
            monthlyAllocation = annualBudgetAllocator.calculateMonthlyAllocation(
                params: params,
                year: year,
                month: month,
            )
        }

        // Category highlights
        let summaries = displayMode == .monthly
            ? monthlySummary.categorySummaries
            : annualSummary.categorySummaries
        let categoryHighlights = Array(summaries.prefix(10))

        // Annual budget progress
        let progressResult = annualBudgetProgressCalculator.calculate(
            budgets: input.budgets,
            transactions: input.annualTransactions,
            year: year,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
        )

        let annualBudgetProgressCalculation: BudgetCalculation?
        let annualBudgetCategoryEntries: [AnnualBudgetEntry]
        if progressResult.overallEntry == nil, progressResult.categoryEntries.isEmpty {
            annualBudgetProgressCalculation = nil
            annualBudgetCategoryEntries = []
        } else {
            annualBudgetProgressCalculation = progressResult.aggregateCalculation
            annualBudgetCategoryEntries = progressResult.categoryEntries
        }

        return DashboardResult(
            monthlySummary: monthlySummary,
            annualSummary: annualSummary,
            monthlyBudgetCalculation: monthlyBudgetCalculation,
            annualBudgetUsage: annualBudgetUsage,
            monthlyAllocation: monthlyAllocation,
            categoryHighlights: categoryHighlights,
            annualBudgetProgressCalculation: annualBudgetProgressCalculation,
            annualBudgetCategoryEntries: annualBudgetCategoryEntries,
        )
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
