import Foundation
import SwiftData

/// ダッシュボードスタックの依存関係
internal struct DashboardStackDependencies {
    internal let repository: DashboardRepository
    internal let dashboardService: DashboardService
}

/// ダッシュボード用ストアを構築するビルダー
///
/// Repository / Service の生成を 1 か所に集約し、
/// 将来的な `@ModelActor` 化での差分を抑える。
internal enum DashboardStackBuilder {
    /// DashboardStore の依存を構築
    internal static func makeDependencies(modelContainer: ModelContainer) async -> DashboardStackDependencies {
        let repository = SwiftDataDashboardRepository(modelContainer: modelContainer)
        let monthPeriodCalculator = MonthPeriodCalculatorFactory.make()
        let dashboardService = DashboardService(monthPeriodCalculator: monthPeriodCalculator)
        return DashboardStackDependencies(
            repository: repository,
            dashboardService: dashboardService,
        )
    }

    /// DashboardStore を構築
    internal static func makeStore(modelContainer: ModelContainer) async -> DashboardStore {
        let dependencies = await makeDependencies(modelContainer: modelContainer)
        return await MainActor.run {
            DashboardStore(
                repository: dependencies.repository,
                dashboardService: dependencies.dashboardService,
            )
        }
    }
}
