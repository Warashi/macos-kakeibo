import Foundation
import Testing

@testable import Kakeibo

@Suite("MonthlyBudgetEntry")
internal struct MonthlyBudgetEntryTests {
    @Test("displayOrderKeyは親子のdisplayOrderを考慮")
    internal func displayOrderKey_usesHierarchy() throws {
        let parent = DomainFixtures.category(name: "固定費", displayOrder: 2)
        let child = DomainFixtures.category(name: "家賃", displayOrder: 10, parent: parent)

        let budget = DomainFixtures.budget(
            amount: 80000,
            category: child,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 1
        )

        let entry = MonthlyBudgetEntry(
            budget: budget,
            title: "\(parent.name) / \(child.name)",
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
        #expect(key.title == "\(parent.name) / \(child.name)")
    }

    @Test("全体予算はisOverallBudgetがtrueになる")
    internal func overallBudget_flagsCorrectly() throws {
        let budget = DomainFixtures.budget(
            amount: 100_000,
            startYear: 2025,
            startMonth: 5,
            endYear: 2025,
            endMonth: 5
        )

        let entry = MonthlyBudgetEntry(
            budget: budget,
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
