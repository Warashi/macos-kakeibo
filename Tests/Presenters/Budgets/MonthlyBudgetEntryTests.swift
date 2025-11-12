import Foundation
import Testing

@testable import Kakeibo

@Suite("MonthlyBudgetEntry")
internal struct MonthlyBudgetEntryTests {
    @Test("displayOrderKeyは親子のdisplayOrderを考慮")
    internal func displayOrderKey_usesHierarchy() throws {
        let parent = Category(name: "固定費", displayOrder: 2)
        let child = Category(name: "家賃", parent: parent, displayOrder: 10)
        parent.addChild(child)

        let budget = Budget(
            amount: 80000,
            category: child,
            year: 2025,
            month: 1,
        )

        let entry = MonthlyBudgetEntry(
            budget: BudgetDTO(from: budget),
            title: child.fullName,
            calculation: BudgetCalculation(
                budgetAmount: 80000,
                actualAmount: 0,
                remainingAmount: 80000,
                usageRate: 0,
                isOverBudget: false,
            ),
            categoryDisplayOrder: child.displayOrder,
            parentCategoryDisplayOrder: parent.displayOrder,
        )

        let key = entry.displayOrderKey

        #expect(key.parentOrder == parent.displayOrder)
        #expect(key.ownOrder == child.displayOrder)
        #expect(key.title == child.fullName)
    }

    @Test("全体予算はisOverallBudgetがtrueになる")
    internal func overallBudget_flagsCorrectly() throws {
        let budget = Budget(
            amount: 100_000,
            year: 2025,
            month: 5,
        )

        let entry = MonthlyBudgetEntry(
            budget: BudgetDTO(from: budget),
            title: "全体予算",
            calculation: BudgetCalculation(
                budgetAmount: 100_000,
                actualAmount: 20000,
                remainingAmount: 80000,
                usageRate: 0.2,
                isOverBudget: false,
            ),
            categoryDisplayOrder: 0,
            parentCategoryDisplayOrder: 0,
        )

        #expect(entry.isOverallBudget)
        #expect(entry.periodDescription.contains("2025年5月"))
    }
}
