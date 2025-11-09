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
        let allocation = AnnualBudgetAllocation(amount: 60000, category: category)
        allocation.config = config
        config.allocations = [allocation]

        let usage = AnnualBudgetUsage(
            year: 2025,
            totalAmount: 100_000,
            usedAmount: 20000,
            remainingAmount: 80000,
            usageRate: 0.2,
            categoryAllocations: [
                CategoryAllocation(
                    categoryId: category.id,
                    categoryName: category.fullName,
                    annualBudgetAmount: 60000,
                    monthlyBudgetAmount: 0,
                    actualAmount: 20000,
                    excessAmount: 20000,
                    allocatableAmount: 20000,
                    remainingAfterAllocation: 0,
                ),
            ],
        )

        let panel = AnnualBudgetPanel(
            year: 2025,
            config: config,
            usage: usage,
            onEdit: {},
        )

        let _: any View = panel
    }

    @Test("コンテンツビルダーは使用状況を反映する")
    internal func contentBuilderReflectsUsage() {
        let category = Category(name: "特別費", allowsAnnualBudget: true)
        let config = AnnualBudgetConfig(year: 2025, totalAmount: 100_000, policy: .automatic)
        let allocation = AnnualBudgetAllocation(amount: 60000, category: category, policyOverride: .manual)
        allocation.config = config
        config.allocations = [allocation]

        let usage = AnnualBudgetUsage(
            year: 2025,
            totalAmount: 100_000,
            usedAmount: 40000,
            remainingAmount: 60000,
            usageRate: 0.4,
            categoryAllocations: [
                CategoryAllocation(
                    categoryId: category.id,
                    categoryName: category.fullName,
                    annualBudgetAmount: 60000,
                    monthlyBudgetAmount: 0,
                    actualAmount: 40000,
                    excessAmount: 0,
                    allocatableAmount: 40000,
                    remainingAfterAllocation: 20000,
                ),
            ],
        )

        let content = AnnualBudgetPanelContentBuilder.build(config: config, usage: usage)
        #expect(content.rows.count == 2)

        let overallRow = content.rows[0]
        #expect(overallRow.isOverall)
        #expect(overallRow.actualAmount == 40000)
        #expect(overallRow.remainingAmount == 60000)

        let categoryRow = content.rows[1]
        #expect(!categoryRow.isOverall)
        #expect(categoryRow.policyDisplayName == "手動充当")
        #expect(categoryRow.actualAmount == 40000)
        #expect(categoryRow.remainingAmount == 20000)
        #expect(abs(categoryRow.usageRate - (2.0 / 3.0)) < 0.001)
    }

    @Test("コンテンツビルダーは使用状況がなくても配分を返す")
    internal func contentBuilderHandlesMissingUsage() {
        let category = Category(name: "特別費", allowsAnnualBudget: true)
        let config = AnnualBudgetConfig(year: 2025, totalAmount: 80000, policy: .automatic)
        let allocation = AnnualBudgetAllocation(amount: 50000, category: category)
        allocation.config = config
        config.allocations = [allocation]

        let content = AnnualBudgetPanelContentBuilder.build(config: config, usage: nil)
        #expect(content.rows.count == 2)

        let summary = content.summary
        #expect(summary.usedAmount == 0)
        #expect(summary.remainingAmount == 80000)
        #expect(summary.usageRate == 0)

        let categoryRow = content.rows[1]
        #expect(categoryRow.actualAmount == 0)
        #expect(categoryRow.remainingAmount == 50000)
        #expect(categoryRow.usageRate == 0)
    }

    @Test("カテゴリ別使用状況テーブルを初期化できる")
    internal func annualBudgetCategoryUsageTableInitialization() {
        let allocations = [
            CategoryAllocation(
                categoryId: UUID(),
                categoryName: "特別費",
                annualBudgetAmount: 50000,
                monthlyBudgetAmount: 0,
                actualAmount: 30000,
                excessAmount: 30000,
                allocatableAmount: 30000,
                remainingAfterAllocation: 0,
            ),
        ]

        let table = AnnualBudgetCategoryUsageTable(allocations: allocations)
        let _: any View = table
    }

    @Test("予算超過時に残額がマイナスになる")
    internal func remainingAmountBecomesNegativeWhenOverBudget() {
        let category = Category(name: "特別費", allowsAnnualBudget: true)
        let config = AnnualBudgetConfig(year: 2025, totalAmount: 100_000, policy: .automatic)
        let allocation = AnnualBudgetAllocation(amount: 60000, category: category)
        allocation.config = config
        config.allocations = [allocation]

        // 使用済み額が予算を超過するケース
        let usage = AnnualBudgetUsage(
            year: 2025,
            totalAmount: 100_000,
            usedAmount: 120_000,
            remainingAmount: -20000,
            usageRate: 1.2,
            categoryAllocations: [
                CategoryAllocation(
                    categoryId: category.id,
                    categoryName: category.fullName,
                    annualBudgetAmount: 60000,
                    monthlyBudgetAmount: 0,
                    actualAmount: 70000,
                    excessAmount: 70000,
                    allocatableAmount: 70000,
                    remainingAfterAllocation: -10000,
                ),
            ],
        )

        let content = AnnualBudgetPanelContentBuilder.build(config: config, usage: usage)

        let overallRow = content.rows[0]
        #expect(overallRow.remainingAmount == -20000)
        #expect(overallRow.isOverBudget)

        let categoryRow = content.rows[1]
        #expect(categoryRow.remainingAmount == -10000)
        #expect(categoryRow.isOverBudget)

        let summary = content.summary
        #expect(summary.remainingAmount == -20000)
    }
}
