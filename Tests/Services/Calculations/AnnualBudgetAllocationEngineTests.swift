import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct AnnualBudgetAllocationEngineTests {
    private let engine: AnnualBudgetAllocationEngine = AnnualBudgetAllocationEngine()

    @Test("累積計算で複数月の充当額を合算できる")
    internal func accumulateMultipleMonths() throws {
        let category = Kakeibo.Category(name: "食費", allowsAnnualBudget: true)
        let config = makeConfig(
            policy: AnnualBudgetPolicy.automatic,
            allocations: [
                AllocationSeed(category: category, amount: 500_000, override: nil),
            ]
        )
        let budgets = [
            Budget(amount: 50_000, category: category, year: 2025, month: 1),
            Budget(amount: 50_000, category: category, year: 2025, month: 2),
        ]
        let params = AllocationCalculationParams(
            transactions: [
                makeTransaction(amount: -80_000, year: 2025, month: 1, category: category),
                makeTransaction(amount: -60_000, year: 2025, month: 2, category: category),
            ],
            budgets: budgets,
            annualBudgetConfig: config
        )

        let accumulationParams = AccumulationParams(
            params: params,
            year: 2025,
            endMonth: 2,
            policy: .automatic,
            annualBudgetConfig: config
        )

        let result = engine.accumulateCategoryAllocations(
            accumulationParams: accumulationParams,
            policyOverrides: [:]
        )

        #expect(result.totalUsed == 40_000)
        let categoryResult = try #require(result.categoryAllocations.first)
        #expect(categoryResult.allocatableAmount == 40_000)
        #expect(categoryResult.actualAmount == 140_000)
    }

    @Test("カテゴリごとのポリシー上書きを尊重する")
    internal func respectsPolicyOverrides() throws {
        let major = Kakeibo.Category(name: "特別支出", allowsAnnualBudget: false)
        let minor = Kakeibo.Category(name: "冠婚葬祭", parent: major, allowsAnnualBudget: false)
        major.addChild(minor)

        let config = makeConfig(
            policy: AnnualBudgetPolicy.disabled,
            allocations: [
                AllocationSeed(category: minor, amount: 200_000, override: .fullCoverage),
            ]
        )

        let params = AllocationCalculationParams(
            transactions: [
                makeTransaction(amount: -30_000, year: 2025, month: 3, category: major, minorCategory: minor),
            ],
            budgets: [],
            annualBudgetConfig: config
        )

        let allocations = engine.calculateCategoryAllocations(
            request: MonthlyCategoryAllocationRequest(
                params: params,
                year: 2025,
                month: 3,
                policy: AnnualBudgetPolicy.disabled,
                policyOverrides: [minor.id: AnnualBudgetPolicy.fullCoverage]
            )
        )

        let allocation = try #require(allocations.first)
        #expect(allocation.allocatableAmount == 30_000)
        #expect(allocation.monthlyBudgetAmount == 0)
    }

    private func makeConfig(
        policy: AnnualBudgetPolicy,
        allocations: [AllocationSeed]
    ) -> AnnualBudgetConfig {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 1_000_000,
            policy: policy
        )
        config.allocations = allocations.map { seed in
            let allocation = AnnualBudgetAllocation(
                amount: seed.amount,
                category: seed.category,
                policyOverride: seed.override
            )
            allocation.config = config
            return allocation
        }
        return config
    }

    private struct AllocationSeed {
        let category: Kakeibo.Category
        let amount: Decimal
        let override: AnnualBudgetPolicy?
    }

    private func makeTransaction(
        amount: Decimal,
        year: Int,
        month: Int,
        category: Kakeibo.Category?,
        minorCategory: Kakeibo.Category? = nil
    ) -> Transaction {
        Transaction(
            date: Date.from(year: year, month: month) ?? Date(),
            title: "テスト取引",
            amount: amount,
            majorCategory: category,
            minorCategory: minorCategory
        )
    }
}
