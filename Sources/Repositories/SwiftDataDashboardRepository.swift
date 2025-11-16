import Foundation
import SwiftData

@DatabaseActor
internal final class SwiftDataDashboardRepository: DashboardRepository {
    private let modelContainer: ModelContainer

    internal init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    internal func fetchSnapshot(year: Int, month: Int) throws -> DashboardSnapshot {
        let context = ModelContext(modelContainer)
        let monthlyTransactions = try fetchTransactions(
            context: context,
            year: year,
            month: month
        )
        let annualTransactions = try fetchTransactions(
            context: context,
            year: year,
            month: nil
        )
        let budgets = try context.fetch(BudgetQueries.budgets(overlapping: year)).map { BudgetDTO(from: $0) }
        let categories = try context.fetch(CategoryQueries.sortedForDisplay()).map { Category(from: $0) }
        let config = try context.fetch(BudgetQueries.annualConfig(for: year)).first.map { AnnualBudgetConfigDTO(from: $0) }

        return DashboardSnapshot(
            monthlyTransactions: monthlyTransactions,
            annualTransactions: annualTransactions,
            budgets: budgets,
            categories: categories,
            config: config
        )
    }

    internal func resolveInitialYear(defaultYear: Int) throws -> Int {
        let context = ModelContext(modelContainer)
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
        month: Int?
    ) throws -> [Transaction] {
        guard let startDate = Date.from(year: year, month: month ?? 1) else {
            return []
        }

        let endDate: Date
        if let month {
            let nextMonth = month == 12 ? 1 : month + 1
            let nextYear = month == 12 ? year + 1 : year
            endDate = Date.from(year: nextYear, month: nextMonth) ?? startDate
        } else {
            endDate = Date.from(year: year + 1, month: 1) ?? startDate
        }

        let descriptor = TransactionQueries.between(
            startDate: startDate,
            endDate: endDate
        )
        let transactions = try context.fetch(descriptor)
        return transactions.map { Transaction(from: $0) }
    }
}
