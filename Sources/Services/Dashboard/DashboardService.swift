import Foundation

/// Dashboard calculation service
///
/// Encapsulates dashboard calculation logic, keeping it separate from UI state management.
/// Works with domain models and can run on any actor.
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
    ///   - snapshot: Input data (transactions, budgets, etc.)
    ///   - year: Target year
    ///   - month: Target month
    ///   - displayMode: Display mode (monthly/annual)
    /// - Returns: Dashboard calculation result
    internal func calculate(
        snapshot: DashboardSnapshot,
        year: Int,
        month: Int,
        displayMode: DashboardStore.DisplayMode,
    ) -> DashboardResult {
        let excludedCategoryIds = snapshot.config?.fullCoverageCategoryIDs(
            includingChildrenFrom: snapshot.categories,
        ) ?? []

        let monthlySummary = aggregator.aggregateMonthly(
            transactions: snapshot.monthlyTransactions,
            categories: snapshot.categories,
            year: year,
            month: month,
            filter: .default,
            savingsGoals: snapshot.savingsGoals
        )

        let annualSummary = aggregator.aggregateAnnually(
            transactions: snapshot.annualTransactions,
            categories: snapshot.categories,
            year: year,
            filter: .default,
            savingsGoals: snapshot.savingsGoals
        )

        let monthlyBudgetCalculation = budgetCalculator.calculateMonthlyBudget(
            input: BudgetCalculator.MonthlyBudgetInput(
                transactions: snapshot.monthlyTransactions,
                budgets: snapshot.budgets,
                categories: snapshot.categories,
                year: year,
                month: month,
                filter: .default,
                excludedCategoryIds: excludedCategoryIds,
            ),
        )

        let (annualBudgetUsage, monthlyAllocation) = calculateAnnualBudgetAllocation(
            snapshot: snapshot,
            year: year,
            month: month,
        )

        let categoryHighlights = calculateCategoryHighlights(
            monthlySummary: monthlySummary,
            annualSummary: annualSummary,
            displayMode: displayMode,
        )

        let (progressCalculation, categoryEntries) = calculateAnnualBudgetProgress(
            snapshot: snapshot,
            year: year,
            excludedCategoryIds: excludedCategoryIds
        )

        let savingsSummary = calculateSavingsSummary(
            goals: snapshot.savingsGoals,
            balances: snapshot.savingsGoalBalances
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
            savingsSummary: savingsSummary
        )
    }

    // MARK: - Private Helpers

    private func calculateAnnualBudgetAllocation(
        snapshot: DashboardSnapshot,
        year: Int,
        month: Int,
    ) -> (AnnualBudgetUsage?, MonthlyAllocation?) {
        guard let config = snapshot.config else {
            return (nil, nil)
        }

        let params = AllocationCalculationParams(
            transactions: snapshot.annualTransactions,
            budgets: snapshot.budgets,
            annualBudgetConfig: config,
            filter: .default,
        )

        let usage = annualBudgetAllocator.calculateAnnualBudgetUsage(
            params: params,
            categories: snapshot.categories,
            upToMonth: month,
        )

        let allocation = annualBudgetAllocator.calculateMonthlyAllocation(
            params: params,
            categories: snapshot.categories,
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
        snapshot: DashboardSnapshot,
        year: Int,
        excludedCategoryIds: Set<UUID>
    ) -> (BudgetCalculation?, [AnnualBudgetEntry]) {
        let progressResult = annualBudgetProgressCalculator.calculate(
            budgets: snapshot.budgets,
            transactions: snapshot.annualTransactions,
            categories: snapshot.categories,
            year: year,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds
        )

        if progressResult.overallEntry == nil, progressResult.categoryEntries.isEmpty {
            return (nil, [])
        } else {
            return (progressResult.aggregateCalculation, progressResult.categoryEntries)
        }
    }

    private func calculateSavingsSummary(
        goals: [SavingsGoal],
        balances: [SavingsGoalBalance]
    ) -> SavingsSummary {
        let balanceMap = Dictionary(uniqueKeysWithValues: balances.map { ($0.goalId, $0) })

        let totalMonthlySavings = goals
            .filter { $0.isActive }
            .reduce(Decimal.zero) { $0 + $1.monthlySavingAmount }

        let goalSummaries = goals.map { goal in
            let balance = balanceMap[goal.id]
            let currentBalance = balance?.balance ?? 0
            let progress: Double = if let targetAmount = goal.targetAmount, targetAmount > 0 {
                min(1.0, NSDecimalNumber(decimal: currentBalance).doubleValue / NSDecimalNumber(decimal: targetAmount).doubleValue)
            } else {
                0.0
            }

            return SavingsGoalSummary(
                goalId: goal.id,
                name: goal.name,
                monthlySavingAmount: goal.monthlySavingAmount,
                currentBalance: currentBalance,
                targetAmount: goal.targetAmount,
                progress: progress
            )
        }

        return SavingsSummary(
            totalMonthlySavings: totalMonthlySavings,
            goalSummaries: goalSummaries
        )
    }
}

// MARK: - Input/Output Types

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
    internal let savingsSummary: SavingsSummary
}

/// 貯蓄サマリ
internal struct SavingsSummary: Sendable {
    internal let totalMonthlySavings: Decimal
    internal let goalSummaries: [SavingsGoalSummary]
}

/// 貯蓄目標サマリ
internal struct SavingsGoalSummary: Sendable {
    internal let goalId: UUID
    internal let name: String
    internal let monthlySavingAmount: Decimal
    internal let currentBalance: Decimal
    internal let targetAmount: Decimal?
    internal let progress: Double
}
