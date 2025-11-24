import Foundation
import SwiftData

@ModelActor
internal actor SwiftDataDashboardRepository: DashboardRepository {
    private var context: ModelContext { modelContext }

    internal func fetchSnapshot(year: Int, month: Int) async throws -> DashboardSnapshot {
        let monthlyTransactions = try await fetchTransactions(
            context: context,
            year: year,
            month: month,
        )
        let annualTransactions = try await fetchTransactions(
            context: context,
            year: year,
            month: nil,
        )
        let budgets = try context.fetch(BudgetQueries.budgets(overlapping: year)).map { Budget(from: $0) }
        let categories = try context.fetch(CategoryQueries.sortedForDisplay()).map { Category(from: $0) }
        let config = try context.fetch(BudgetQueries.annualConfig(for: year)).first.map { AnnualBudgetConfig(from: $0) }

        // 貯蓄目標と残高を取得
        let savingsGoalDescriptor = FetchDescriptor<SwiftDataSavingsGoal>()
        let swiftDataSavingsGoals = try context.fetch(savingsGoalDescriptor)
        let savingsGoals = swiftDataSavingsGoals.map { SavingsGoal(from: $0) }

        let balanceDescriptor = FetchDescriptor<SwiftDataSavingsGoalBalance>()
        let swiftDataBalances = try context.fetch(balanceDescriptor)
        let savingsGoalBalances = swiftDataBalances.map { SavingsGoalBalance(from: $0) }

        // 定期支払いのデータを取得
        let definitionsDescriptor = RecurringPaymentQueries.definitions()
        let swiftDataDefinitions = try context.fetch(definitionsDescriptor)
        let recurringPaymentDefinitions = swiftDataDefinitions.map { RecurringPaymentDefinition(from: $0) }

        let occurrencesDescriptor = RecurringPaymentQueries.occurrences()
        let swiftDataOccurrences = try context.fetch(occurrencesDescriptor)
        let recurringPaymentOccurrences = swiftDataOccurrences.map { RecurringPaymentOccurrence(from: $0) }

        let balancesDescriptor = RecurringPaymentQueries.balances()
        let swiftDataRecurringBalances = try context.fetch(balancesDescriptor)
        let recurringPaymentBalances = swiftDataRecurringBalances.map { RecurringPaymentSavingBalance(from: $0) }

        return DashboardSnapshot(
            monthlyTransactions: monthlyTransactions,
            annualTransactions: annualTransactions,
            budgets: budgets,
            categories: categories,
            config: config,
            savingsGoals: savingsGoals,
            savingsGoalBalances: savingsGoalBalances,
            recurringPaymentDefinitions: recurringPaymentDefinitions,
            recurringPaymentOccurrences: recurringPaymentOccurrences,
            recurringPaymentBalances: recurringPaymentBalances,
        )
    }

    internal func resolveInitialYear(defaultYear: Int) async throws -> Int {
        if try context.fetch(BudgetQueries.annualConfig(for: defaultYear)).first != nil {
            return defaultYear
        }
        return try context.fetch(BudgetQueries.latestAnnualConfig()).first?.year ?? defaultYear
    }
}

private extension SwiftDataDashboardRepository {
    func fetchTransactions(
        context: ModelContext,
        year: Int,
        month: Int?,
    ) async throws -> [Transaction] {
        let (startDate, endDate): (Date, Date)

        if let month {
            // 月指定の場合、MonthPeriodCalculatorを使用
            let monthPeriodCalculator = MonthPeriodCalculatorFactory.make()
            if let period = monthPeriodCalculator.calculatePeriod(for: year, month: month) {
                startDate = period.start
                endDate = period.end
            } else {
                // フォールバック: 従来の月初〜月末
                guard let fallbackStart = Date.from(year: year, month: month) else {
                    return []
                }
                let nextMonth = month == 12 ? 1 : month + 1
                let nextYear = month == 12 ? year + 1 : year
                startDate = fallbackStart
                endDate = Date.from(year: nextYear, month: nextMonth) ?? fallbackStart
            }
        } else {
            // 年全体の場合、年初〜年末
            guard let yearStart = Date.from(year: year, month: 1) else {
                return []
            }
            startDate = yearStart
            endDate = Date.from(year: year + 1, month: 1) ?? yearStart
        }

        let descriptor = TransactionQueries.between(
            startDate: startDate,
            endDate: endDate,
        )
        let transactions = try context.fetch(descriptor)
        return transactions.map { Transaction(from: $0) }
    }
}
