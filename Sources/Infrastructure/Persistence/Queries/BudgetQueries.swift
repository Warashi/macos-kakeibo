import Foundation
import SwiftData

/// 予算関連のフェッチビルダー
internal enum BudgetQueries {
    internal static func allBudgets() -> ModelFetchRequest<SwiftDataBudget> {
        ModelFetchFactory.make()
    }

    internal static func categoriesForBudgetList() -> ModelFetchRequest<SwiftDataCategory> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\SwiftDataCategory.displayOrder),
                SortDescriptor(\SwiftDataCategory.name, order: .forward),
            ],
        )
    }

    internal static func annualConfig(for year: Int) -> ModelFetchRequest<SwiftDataAnnualBudgetConfig> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.year == year },
            fetchLimit: 1,
        )
    }

    internal static func latestAnnualConfig() -> ModelFetchRequest<SwiftDataAnnualBudgetConfig> {
        ModelFetchFactory.make(
            sortBy: [SortDescriptor(\SwiftDataAnnualBudgetConfig.year, order: .reverse)],
            fetchLimit: 1,
        )
    }

    internal static func budgets(overlapping year: Int) -> ModelFetchRequest<SwiftDataBudget> {
        ModelFetchFactory.make(
            predicate: #Predicate {
                $0.startYear <= year && $0.endYear >= year
            },
            sortBy: [
                SortDescriptor(\SwiftDataBudget.startYear),
                SortDescriptor(\SwiftDataBudget.startMonth),
                SortDescriptor(\SwiftDataBudget.createdAt),
            ],
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<SwiftDataBudget> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1,
        )
    }
}
