import Foundation
import SwiftData

/// 予算関連のフェッチビルダー
internal enum BudgetQueries {
    internal static func allBudgets() -> ModelFetchRequest<Budget> {
        ModelFetchFactory.make()
    }

    internal static func categoriesForBudgetList() -> ModelFetchRequest<Category> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\Category.displayOrder),
                SortDescriptor(\Category.name, order: .forward),
            ]
        )
    }

    internal static func annualConfig(for year: Int) -> ModelFetchRequest<AnnualBudgetConfig> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.year == year },
            fetchLimit: 1
        )
    }

    internal static func latestAnnualConfig() -> ModelFetchRequest<AnnualBudgetConfig> {
        ModelFetchFactory.make(
            sortBy: [SortDescriptor(\AnnualBudgetConfig.year, order: .reverse)],
            fetchLimit: 1
        )
    }

    internal static func budgets(overlapping year: Int) -> ModelFetchRequest<Budget> {
        ModelFetchFactory.make(
            predicate: #Predicate {
                $0.startYear <= year && $0.endYear >= year
            },
            sortBy: [
                SortDescriptor(\Budget.startYear),
                SortDescriptor(\Budget.startMonth),
                SortDescriptor(\Budget.createdAt),
            ]
        )
    }
}
