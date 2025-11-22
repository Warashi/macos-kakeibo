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

        let reconciledTransactionIds = collectReconciledTransactionIds(
            from: snapshot.recurringPaymentOccurrences,
        )
        let filter = buildAggregationFilter(reconciledTransactionIds: reconciledTransactionIds)
        let monthlyRecurringPaymentAllocation = calculateMonthlyRecurringPaymentAllocation(
            from: snapshot.recurringPaymentDefinitions,
        )

        let (monthlySummary, annualSummary) = calculateSummaries(
            params: SummaryCalculationParams(
                snapshot: snapshot,
                year: year,
                month: month,
                filter: filter,
                monthlyRecurringPaymentAllocation: monthlyRecurringPaymentAllocation,
            ),
        )

        let result = calculateBudgetsAndProgress(
            params: BudgetCalculationParams(
                snapshot: snapshot,
                year: year,
                month: month,
                excludedCategoryIds: excludedCategoryIds,
                monthlySummary: monthlySummary,
                annualSummary: annualSummary,
                displayMode: displayMode,
            ),
        )

        return DashboardResult(
            monthlySummary: monthlySummary,
            annualSummary: annualSummary,
            monthlyBudgetCalculation: result.monthlyBudgetCalculation,
            annualBudgetUsage: result.annualBudgetUsage,
            monthlyAllocation: result.monthlyAllocation,
            categoryHighlights: result.categoryHighlights,
            annualBudgetProgressCalculation: result.progressCalculation,
            annualBudgetCategoryEntries: result.categoryEntries,
            savingsSummary: result.savingsSummary,
            recurringPaymentSummary: result.recurringPaymentSummary,
        )
    }

    // MARK: - Private Helpers

    /// サマリ計算パラメータ
    private struct SummaryCalculationParams {
        internal let snapshot: DashboardSnapshot
        internal let year: Int
        internal let month: Int
        internal let filter: AggregationFilter
        internal let monthlyRecurringPaymentAllocation: Decimal
    }

    private struct BudgetCalculationParams {
        internal let snapshot: DashboardSnapshot
        internal let year: Int
        internal let month: Int
        internal let excludedCategoryIds: [UUID]
        internal let monthlySummary: MonthlySummary
        internal let annualSummary: AnnualSummary
        internal let displayMode: DashboardStore.DisplayMode
    }

    /// 予算・進捗計算結果
    private struct BudgetAndProgressResult {
        internal let monthlyBudgetCalculation: MonthlyBudgetCalculation
        internal let annualBudgetUsage: AnnualBudgetUsage?
        internal let monthlyAllocation: MonthlyAllocation?
        internal let categoryHighlights: [CategorySummary]
        internal let progressCalculation: AnnualBudgetProgressCalculation?
        internal let categoryEntries: [AnnualBudgetCategoryEntry]
        internal let savingsSummary: SavingsSummary
        internal let recurringPaymentSummary: RecurringPaymentSummary
    }

    /// 予算・進捗・サマリを計算
    /// - Parameter params: 予算計算パラメータ
    /// - Returns: 予算・進捗計算結果
    private func calculateBudgetsAndProgress(params: BudgetCalculationParams) -> BudgetAndProgressResult {
        let snapshot = params.snapshot
        let year = params.year
        let month = params.month
        let excludedCategoryIds = params.excludedCategoryIds
        let monthlySummary = params.monthlySummary
        let annualSummary = params.annualSummary
        let displayMode = params.displayMode

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
            excludedCategoryIds: excludedCategoryIds,
        )

        let savingsSummary = calculateSavingsSummary(
            goals: snapshot.savingsGoals,
            balances: snapshot.savingsGoalBalances,
        )

        let recurringPaymentSummary = calculateRecurringPaymentSummary(
            params: RecurringPaymentSummaryParams(
                definitions: snapshot.recurringPaymentDefinitions,
                occurrences: snapshot.recurringPaymentOccurrences,
                balances: snapshot.recurringPaymentBalances,
                year: year,
                month: month,
            ),
        )

        return BudgetAndProgressResult(
            monthlyBudgetCalculation: monthlyBudgetCalculation,
            annualBudgetUsage: annualBudgetUsage,
            monthlyAllocation: monthlyAllocation,
            categoryHighlights: categoryHighlights,
            progressCalculation: progressCalculation,
            categoryEntries: categoryEntries,
            savingsSummary: savingsSummary,
            recurringPaymentSummary: recurringPaymentSummary,
        )
    }

    /// 月次・年次サマリを計算
    /// - Parameter params: サマリ計算パラメータ
    /// - Returns: (月次サマリ, 年次サマリ)
    private func calculateSummaries(
        params: SummaryCalculationParams,
    ) -> (MonthlySummary, AnnualSummary) {
        let monthlySummary = aggregator.aggregateMonthly(
            transactions: params.snapshot.monthlyTransactions,
            categories: params.snapshot.categories,
            year: params.year,
            month: params.month,
            filter: params.filter,
            savingsGoals: params.snapshot.savingsGoals,
            recurringPaymentAllocation: params.monthlyRecurringPaymentAllocation,
        )

        let annualSummary = aggregator.aggregateAnnually(
            transactions: params.snapshot.annualTransactions,
            categories: params.snapshot.categories,
            year: params.year,
            filter: params.filter,
            savingsGoals: params.snapshot.savingsGoals,
            recurringPaymentDefinitions: params.snapshot.recurringPaymentDefinitions,
        )

        return (monthlySummary, annualSummary)
    }

    /// 突合済みトランザクションIDを収集
    /// - Parameter occurrences: 定期支払い発生一覧
    /// - Returns: 突合済みトランザクションIDのセット
    private func collectReconciledTransactionIds(
        from occurrences: [RecurringPaymentOccurrence],
    ) -> Set<UUID> {
        Set(occurrences.compactMap(\.transactionId))
    }

    /// 集計用フィルタを構築
    /// - Parameters:
    ///   - reconciledTransactionIds: 突合済みトランザクションID
    /// - Returns: 集計フィルタ
    private func buildAggregationFilter(
        reconciledTransactionIds: Set<UUID>,
    ) -> AggregationFilter {
        AggregationFilter(
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            financialInstitutionId: nil,
            categoryId: nil,
            excludedTransactionIds: reconciledTransactionIds,
        )
    }

    /// 月次積立額を計算
    /// - Parameter definitions: 定期支払い定義一覧
    /// - Returns: 月次積立額の合計
    private func calculateMonthlyRecurringPaymentAllocation(
        from definitions: [RecurringPaymentDefinition],
    ) -> Decimal {
        definitions
            .filter { $0.savingStrategy != .disabled }
            .reduce(Decimal.zero) { $0 + $1.monthlySavingAmount }
    }

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
        excludedCategoryIds: Set<UUID>,
    ) -> (BudgetCalculation?, [AnnualBudgetEntry]) {
        let progressResult = annualBudgetProgressCalculator.calculate(
            budgets: snapshot.budgets,
            transactions: snapshot.annualTransactions,
            categories: snapshot.categories,
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

    private func calculateSavingsSummary(
        goals: [SavingsGoal],
        balances: [SavingsGoalBalance],
    ) -> SavingsSummary {
        let balanceMap = Dictionary(uniqueKeysWithValues: balances.map { ($0.goalId, $0) })

        let totalMonthlySavings = goals
            .filter(\.isActive)
            .reduce(Decimal.zero) { $0 + $1.monthlySavingAmount }

        let goalSummaries = goals.map { goal in
            let balance = balanceMap[goal.id]
            let currentBalance = balance?.balance ?? 0
            let progress: Double = if let targetAmount = goal.targetAmount, targetAmount > 0 {
                min(
                    1.0,
                    NSDecimalNumber(decimal: currentBalance).doubleValue / NSDecimalNumber(decimal: targetAmount)
                        .doubleValue,
                )
            } else {
                0.0
            }

            return SavingsGoalSummary(
                goalId: goal.id,
                name: goal.name,
                monthlySavingAmount: goal.monthlySavingAmount,
                currentBalance: currentBalance,
                targetAmount: goal.targetAmount,
                progress: progress,
            )
        }

        return SavingsSummary(
            totalMonthlySavings: totalMonthlySavings,
            goalSummaries: goalSummaries,
        )
    }

    /// 定期支払いサマリの計算パラメータ
    private struct RecurringPaymentSummaryParams {
        internal let definitions: [RecurringPaymentDefinition]
        internal let occurrences: [RecurringPaymentOccurrence]
        internal let balances: [RecurringPaymentSavingBalance]
        internal let year: Int
        internal let month: Int
    }

    private func calculateRecurringPaymentSummary(
        params: RecurringPaymentSummaryParams,
    ) -> RecurringPaymentSummary {
        let year = params.year
        let month = params.month
        let definitions = params.definitions
        let occurrences = params.occurrences
        let balances = params.balances
        // 当月の開始日・終了日を計算
        guard let monthStart = Date.from(year: year, month: month),
              let monthEnd = Date.from(year: year, month: month == 12 ? 1 : month + 1) else {
            return RecurringPaymentSummary(
                totalMonthlyAmount: 0,
                currentMonthExpected: 0,
                currentMonthActual: 0,
                currentMonthRemaining: 0,
                definitions: [],
            )
        }

        // 当月のOccurrenceをフィルタリング
        let currentMonthOccurrences = occurrences.filter { occurrence in
            occurrence.scheduledDate >= monthStart && occurrence.scheduledDate < monthEnd
        }

        // DefinitionIDでグループ化
        let occurrencesByDefinition = Dictionary(
            grouping: currentMonthOccurrences,
            by: { $0.definitionId },
        )

        // 月額積立合計を計算
        let totalMonthlyAmount = definitions
            .filter { $0.savingStrategy != .disabled }
            .reduce(Decimal.zero) { $0 + $1.monthlySavingAmount }

        // 当月予定・実績・未払いを計算
        var currentMonthExpected = Decimal.zero
        var currentMonthActual = Decimal.zero

        let definitionSummaries = definitions.map { definition in
            let monthOccurrences = occurrencesByDefinition[definition.id] ?? []
            let currentMonthOccurrence: OccurrenceSummary? = if let occurrence = monthOccurrences.first {
                OccurrenceSummary(
                    expectedAmount: occurrence.expectedAmount,
                    actualAmount: occurrence.actualAmount,
                    isCompleted: occurrence.isCompleted,
                    scheduledDate: occurrence.scheduledDate,
                )
            } else {
                nil
            }

            // 当月予定・実績を集計
            for occurrence in monthOccurrences {
                currentMonthExpected += occurrence.expectedAmount
                currentMonthActual += occurrence.actualAmount ?? 0
            }

            return RecurringPaymentDefinitionSummary(
                definitionId: definition.id,
                name: definition.name,
                monthlySavingAmount: definition.monthlySavingAmount,
                currentMonthOccurrence: currentMonthOccurrence,
            )
        }

        let currentMonthRemaining = max(0, currentMonthExpected - currentMonthActual)

        return RecurringPaymentSummary(
            totalMonthlyAmount: totalMonthlyAmount,
            currentMonthExpected: currentMonthExpected,
            currentMonthActual: currentMonthActual,
            currentMonthRemaining: currentMonthRemaining,
            definitions: definitionSummaries,
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
    internal let recurringPaymentSummary: RecurringPaymentSummary
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

/// 定期支払いサマリ
internal struct RecurringPaymentSummary: Sendable {
    /// 月額積立合計
    internal let totalMonthlyAmount: Decimal
    /// 当月予定支払額
    internal let currentMonthExpected: Decimal
    /// 当月実績支払額
    internal let currentMonthActual: Decimal
    /// 当月未払い分
    internal let currentMonthRemaining: Decimal
    /// 定義別サマリ
    internal let definitions: [RecurringPaymentDefinitionSummary]
}

/// 定期支払い定義別サマリ
internal struct RecurringPaymentDefinitionSummary: Sendable {
    internal let definitionId: UUID
    internal let name: String
    internal let monthlySavingAmount: Decimal
    internal let currentMonthOccurrence: OccurrenceSummary?
}

/// 発生予定サマリ
internal struct OccurrenceSummary: Sendable {
    internal let expectedAmount: Decimal
    internal let actualAmount: Decimal?
    internal let isCompleted: Bool
    internal let scheduledDate: Date
}
