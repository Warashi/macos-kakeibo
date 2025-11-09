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

    @Test("コンテンツビルダーは使用状況を反映する")
    internal func contentBuilderReflectsUsage() {
        let category = Category(name: "特別費", allowsAnnualBudget: true)
        let config = AnnualBudgetConfig(year: 2025, totalAmount: 100_000, policy: .automatic)
        let allocation = AnnualBudgetAllocation(amount: 60_000, category: category, policyOverride: .manual)
        allocation.config = config
        config.allocations = [allocation]

        let usage = AnnualBudgetUsage(
            year: 2025,
            totalAmount: 100_000,
            usedAmount: 40_000,
            remainingAmount: 60_000,
            usageRate: 0.4,
            categoryAllocations: [
                CategoryAllocation(
                    categoryId: category.id,
                    categoryName: category.fullName,
                    annualBudgetAmount: 60_000,
                    monthlyBudgetAmount: 0,
                    actualAmount: 40_000,
                    excessAmount: 0,
                    allocatableAmount: 40_000,
                    remainingAfterAllocation: 20_000
                ),
            ]
        )

        let content = AnnualBudgetPanelContentBuilder.build(config: config, usage: usage)
        #expect(content.rows.count == 2)

        let overallRow = content.rows[0]
        #expect(overallRow.isOverall)
        #expect(overallRow.actualAmount == 40_000)
        #expect(overallRow.remainingAmount == 60_000)

        let categoryRow = content.rows[1]
        #expect(!categoryRow.isOverall)
        #expect(categoryRow.policyDisplayName == "手動充当")
        #expect(categoryRow.actualAmount == 40_000)
        #expect(categoryRow.remainingAmount == 20_000)
        #expect(abs(categoryRow.usageRate - (2.0 / 3.0)) < 0.001)
    }

    @Test("コンテンツビルダーは使用状況がなくても配分を返す")
    internal func contentBuilderHandlesMissingUsage() {
        let category = Category(name: "特別費", allowsAnnualBudget: true)
        let config = AnnualBudgetConfig(year: 2025, totalAmount: 80_000, policy: .automatic)
        let allocation = AnnualBudgetAllocation(amount: 50_000, category: category)
        allocation.config = config
        config.allocations = [allocation]

        let content = AnnualBudgetPanelContentBuilder.build(config: config, usage: nil)
        #expect(content.rows.count == 2)

        let summary = content.summary
        #expect(summary.usedAmount == 0)
        #expect(summary.remainingAmount == 80_000)
        #expect(summary.usageRate == 0)

        let categoryRow = content.rows[1]
        #expect(categoryRow.actualAmount == 0)
        #expect(categoryRow.remainingAmount == 50_000)
        #expect(categoryRow.usageRate == 0)
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
