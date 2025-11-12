import Foundation

/// 月次予算の表示用エントリ
internal struct MonthlyBudgetEntry: Identifiable {
    internal let budget: BudgetDTO
    internal let title: String
    internal let calculation: BudgetCalculation
    internal let categoryDisplayOrder: Int
    internal let parentCategoryDisplayOrder: Int

    internal var id: UUID { budget.id }

    internal var periodDescription: String {
        budget.periodDescription
    }

    internal var isOverallBudget: Bool {
        budget.categoryId == nil
    }

    /// ソート用にカテゴリのdisplayOrderを親子で考慮した順序情報を返す
    internal var displayOrderKey: CategoryDisplayOrderKey {
        let parentOrder = parentCategoryDisplayOrder
        let ownOrder = categoryDisplayOrder
        return CategoryDisplayOrderKey(parentOrder: parentOrder, ownOrder: ownOrder, title: title)
    }
}

/// カテゴリの表示順序を表すキー
internal struct CategoryDisplayOrderKey: Comparable {
    internal let parentOrder: Int
    internal let ownOrder: Int
    internal let title: String

    internal static func < (lhs: CategoryDisplayOrderKey, rhs: CategoryDisplayOrderKey) -> Bool {
        if lhs.parentOrder != rhs.parentOrder {
            return lhs.parentOrder < rhs.parentOrder
        }
        if lhs.ownOrder != rhs.ownOrder {
            return lhs.ownOrder < rhs.ownOrder
        }
        return lhs.title < rhs.title
    }
}
