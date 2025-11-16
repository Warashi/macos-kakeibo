import Foundation
import SwiftData

/// 予算関連のフェッチビルダー
internal enum BudgetQueries {
    internal static func allBudgets() -> ModelFetchRequest<Budget> {
        ModelFetchFactory.make()
    }

    internal static func categoriesForBudgetList() -> ModelFetchRequest<CategoryEntity> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\CategoryEntity.displayOrder),
                SortDescriptor(\CategoryEntity.name, order: .forward),
            ],
        )
    }

    internal static func annualConfig(for year: Int) -> ModelFetchRequest<AnnualBudgetConfig> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.year == year },
            fetchLimit: 1,
        )
    }

    internal static func latestAnnualConfig() -> ModelFetchRequest<AnnualBudgetConfig> {
        ModelFetchFactory.make(
            sortBy: [SortDescriptor(\AnnualBudgetConfig.year, order: .reverse)],
            fetchLimit: 1,
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
            ],
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<Budget> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1,
        )
    }
}
