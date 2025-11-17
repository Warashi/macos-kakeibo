import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct AnnualBudgetAllocationEngineTests {
    private let engine: AnnualBudgetAllocationEngine = AnnualBudgetAllocationEngine()

    @Test("累積計算で複数月の充当額を合算できる")
    internal func accumulateMultipleMonths() throws {
        let category = DomainFixtures.category(name: "食費", allowsAnnualBudget: true)
        let config = makeConfig(
            policy: AnnualBudgetPolicy.automatic,
            allocations: [
                AllocationSeed(category: category, amount: 500_000, override: nil),
            ],
        )
        let budgets = [
            DomainFixtures.budget(amount: 50000, category: category, startYear: 2025, startMonth: 1),
            DomainFixtures.budget(amount: 50000, category: category, startYear: 2025, startMonth: 2),
        ]
        let transactions = [
            makeTransaction(amount: -80000, year: 2025, month: 1, category: category),
            makeTransaction(amount: -60000, year: 2025, month: 2, category: category),
        ]
        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        let accumulationParams = AccumulationParams(
            params: params,
            year: 2025,
            endMonth: 2,
            policy: .automatic,
            annualBudgetConfig: config,
        )

        let categories = [category]
        let result = engine.accumulateCategoryAllocations(
            accumulationParams: accumulationParams,
            policyOverrides: [:],
            categories: categories,
        )

        #expect(result.totalUsed == 40000)
        let categoryResult = try #require(result.categoryAllocations.first)
        #expect(categoryResult.allocatableAmount == 40000)
        #expect(categoryResult.actualAmount == 140_000)
    }

    @Test("カテゴリごとのポリシー上書きを尊重する")
    internal func respectsPolicyOverrides() throws {
        let major = DomainFixtures.category(name: "特別支出")
        let minor = DomainFixtures.category(name: "冠婚葬祭", parent: major)

        let config = makeConfig(
            policy: AnnualBudgetPolicy.disabled,
            allocations: [
                AllocationSeed(category: minor, amount: 200_000, override: .fullCoverage),
            ],
        )

        let transactions = [
            makeTransaction(amount: -30000, year: 2025, month: 3, category: major, minorCategory: minor),
        ]
        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: [],
            annualBudgetConfig: config,
        )

        let categories = [major, minor]
        let allocations = engine.calculateCategoryAllocations(
            request: MonthlyCategoryAllocationRequest(
                params: params,
                year: 2025,
                month: 3,
                policy: AnnualBudgetPolicy.disabled,
                policyOverrides: [minor.id: AnnualBudgetPolicy.fullCoverage],
            ),
            categories: categories,
        )

        let allocation = try #require(allocations.first)
        #expect(allocation.allocatableAmount == 30000)
        #expect(allocation.monthlyBudgetAmount == 0)
    }

    private func makeConfig(
        policy: AnnualBudgetPolicy,
        allocations: [AllocationSeed],
    ) -> AnnualBudgetConfig {
        let allocations = allocations.map { seed in
            DomainFixtures.annualBudgetAllocation(
                amount: seed.amount,
                category: seed.category,
                policyOverride: seed.override,
                configId: nil
            )
        }
        return DomainFixtures.annualBudgetConfig(
            year: 2025,
            totalAmount: 1_000_000,
            policy: policy,
            allocations: allocations
        )
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
        minorCategory: Kakeibo.Category? = nil,
    ) -> Transaction {
        DomainFixtures.transaction(
            date: Date.from(year: year, month: month) ?? Date(),
            title: "テスト取引",
            amount: amount,
            majorCategory: category,
            minorCategory: minorCategory
        )
    }
}
