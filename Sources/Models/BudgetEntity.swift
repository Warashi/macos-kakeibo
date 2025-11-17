import Foundation

/// 予算タイプ
internal enum BudgetType: String, Codable {
    case monthly // 月次予算
    case annual // 年次特別枠
}

typealias BudgetEntity = SwiftDataBudget
typealias AnnualBudgetConfigEntity = SwiftDataAnnualBudgetConfig
typealias AnnualBudgetAllocationEntity = SwiftDataAnnualBudgetAllocation
