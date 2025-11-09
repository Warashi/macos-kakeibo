import SwiftUI
import Testing

@testable import Kakeibo

@Suite("AnnualBudgetPanel Tests")
@MainActor
internal struct AnnualBudgetPanelTests {
    @Test("年次特別枠パネルを初期化できる")
    internal func annualBudgetPanelInitialization() {
        let category = Category(name: "特別費", allowsAnnualBudget: true)
        let config = AnnualBudgetConfig(year: 2025, totalAmount: 100_000, policy: .automatic)
        let allocation = AnnualBudgetAllocation(amount: 60_000, category: category)
        allocation.config = config
        config.allocations = [allocation]

        let usage = AnnualBudgetUsage(
            year: 2025,
            totalAmount: 100_000,
            usedAmount: 20_000,
            remainingAmount: 80_000,
            usageRate: 0.2,
            categoryAllocations: [
                CategoryAllocation(
                    categoryId: category.id,
                    categoryName: category.fullName,
                    annualBudgetAmount: 60_000,
                    monthlyBudgetAmount: 0,
                    actualAmount: 20_000,
                    excessAmount: 20_000,
                    allocatableAmount: 20_000,
                    remainingAfterAllocation: 0
                ),
            ]
        )

        let panel = AnnualBudgetPanel(
            year: 2025,
            config: config,
            usage: usage,
            onEdit: {}
        )

        let _: any View = panel
    }

    @Test("カテゴリ別使用状況テーブルを初期化できる")
    internal func annualBudgetCategoryUsageTableInitialization() {
        let allocations = [
            CategoryAllocation(
                categoryId: UUID(),
                categoryName: "特別費",
                annualBudgetAmount: 50_000,
                monthlyBudgetAmount: 0,
                actualAmount: 30_000,
                excessAmount: 30_000,
                allocatableAmount: 30_000,
                remainingAfterAllocation: 0
            ),
        ]

        let table = AnnualBudgetCategoryUsageTable(allocations: allocations)
        let _: any View = table
    }
}
