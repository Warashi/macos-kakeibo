import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct AnnualBudgetAllocationEngineTests {
    private let engine = AnnualBudgetAllocationEngine()

    @Test("累積計算で複数月の充当額を合算できる")
    internal func accumulateMultipleMonths() throws {
        let category = Category(name: "食費", allowsAnnualBudget: true)
        let config = makeConfig(
            policy: .automatic,
            allocations: [
                (category, 500_000, nil),
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
        let major = Category(name: "特別支出", allowsAnnualBudget: false)
        let minor = Category(name: "冠婚葬祭", parent: major, allowsAnnualBudget: false)
        major.addChild(minor)

        let config = makeConfig(
            policy: .disabled,
            allocations: [
                (minor, 200_000, .fullCoverage),
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
            params: params,
            year: 2025,
            month: 3,
            policy: .disabled,
            policyOverrides: [minor.id: .fullCoverage]
        )

        let allocation = try #require(allocations.first)
        #expect(allocation.allocatableAmount == 30_000)
        #expect(allocation.monthlyBudgetAmount == 0)
    }

    private func makeConfig(
        policy: AnnualBudgetPolicy,
        allocations: [(Category, Decimal, AnnualBudgetPolicy?)]
    ) -> AnnualBudgetConfig {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 1_000_000,
            policy: policy
        )
        config.allocations = allocations.map { category, amount, override in
            let allocation = AnnualBudgetAllocation(
                amount: amount,
                category: category,
                policyOverride: override
            )
            allocation.config = config
            return allocation
        }
        return config
    }

    private func makeTransaction(
        amount: Decimal,
        year: Int,
        month: Int,
        category: Category?,
        minorCategory: Category? = nil
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
