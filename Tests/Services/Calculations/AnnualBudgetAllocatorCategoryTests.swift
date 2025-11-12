import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct AnnualBudgetAllocatorCategoryTests {
    private let allocator: AnnualBudgetAllocator = AnnualBudgetAllocator()

    @Test("年次特別枠累積計算：実績0のカテゴリも表示される")
    internal func annualBudgetUsage_showsZeroCategories() throws {
        // Given
        let category1 = Category(name: "旅行", allowsAnnualBudget: true)
        let category2 = Category(name: "医療", allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -50000, category: category1),
        ]
        let config = makeConfig(
            allocations: [
                AllocationSeed(category: category1, amount: 100_000, override: .fullCoverage),
                AllocationSeed(category: category2, amount: 50000, override: .fullCoverage),
            ],
        )

        let params = AllocationCalculationParams(
            transactions: transactions.map { TransactionDTO(from: $0) },
            budgets: [],
            annualBudgetConfig: AnnualBudgetConfigDTO(from: config),
        )

        // When
        let categories = [CategoryDTO(from: category1), CategoryDTO(from: category2)]
        let result = allocator.calculateAnnualBudgetUsage(
            params: params,
            categories: categories,
            upToMonth: 11,
        )

        // Then
        #expect(result.categoryAllocations.count == 2)

        let category1Allocation = result.categoryAllocations.first { $0.categoryId == category1.id }
        #expect(category1Allocation != nil)
        #expect(category1Allocation?.annualBudgetAmount == 100_000)
        #expect(category1Allocation?.actualAmount == 50000)
        #expect(category1Allocation?.allocatableAmount == 50000)

        let category2Allocation = result.categoryAllocations.first { $0.categoryId == category2.id }
        #expect(category2Allocation != nil)
        #expect(category2Allocation?.annualBudgetAmount == 50000)
        #expect(category2Allocation?.actualAmount == 0)
        #expect(category2Allocation?.allocatableAmount == 0)
    }

    @Test("年次特別枠累積計算：当月までの実績を集計する")
    internal func annualBudgetUsage_accumulatesUpToMonth() throws {
        // Given
        let category = Category(name: "教育", allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -40000, category: category, month: 1),
            createTransaction(amount: -60000, category: category, month: 2),
            createTransaction(amount: -20000, category: category, month: 4),
        ]
        let budgets = [
            Budget(amount: 30000, category: category, year: 2025, month: 1),
            Budget(amount: 30000, category: category, year: 2025, month: 2),
            Budget(amount: 30000, category: category, year: 2025, month: 4),
        ]
        let config = makeConfig(
            allocations: [
                AllocationSeed(category: category, amount: 120_000, override: nil),
            ],
        )

        let params = AllocationCalculationParams(
            transactions: transactions.map { TransactionDTO(from: $0) },
            budgets: budgets.map { BudgetDTO(from: $0) },
            annualBudgetConfig: AnnualBudgetConfigDTO(from: config),
        )

        // When
        let categories = [CategoryDTO(from: category)]
        let result = allocator.calculateAnnualBudgetUsage(
            params: params,
            categories: categories,
            upToMonth: 2,
        )
        let allocation = try #require(result.categoryAllocations.first { $0.categoryId == category.id })

        // Then
        #expect(allocation.annualBudgetAmount == 120_000)
        #expect(allocation.actualAmount == 100_000) // 1〜2月の実績のみ
        #expect(allocation.monthlyBudgetAmount == 60000) // 1〜2月の予算のみ
        #expect(allocation.allocatableAmount == 40000)
        #expect(allocation.annualBudgetRemainingAmount == 80000)
        #expect(result.usedAmount == 40000)
    }

    @Test("親子カテゴリの配分が重複計上されない")
    internal func annualBudgetUsage_parentChildNoDoubleCount() throws {
        let major = Category(name: "特別費", allowsAnnualBudget: true)
        let minor = Category(name: "旅行", parent: major, allowsAnnualBudget: true)
        major.addChild(minor)

        let transactions = [
            createTransaction(amount: -25000, category: major, minorCategory: minor),
        ]
        let config = makeConfig(
            allocations: [
                AllocationSeed(category: major, amount: 150_000, override: nil),
                AllocationSeed(category: minor, amount: 50000, override: nil),
            ],
        )

        let params = AllocationCalculationParams(
            transactions: transactions.map { TransactionDTO(from: $0) },
            budgets: [],
            annualBudgetConfig: AnnualBudgetConfigDTO(from: config),
        )

        let categories = [CategoryDTO(from: major), CategoryDTO(from: minor)]
        let result = allocator.calculateAnnualBudgetUsage(
            params: params,
            categories: categories,
            upToMonth: 11,
        )

        #expect(result.usedAmount == 25000)
        let majorAllocation = try #require(result.categoryAllocations.first { $0.categoryId == major.id })
        let minorAllocation = try #require(result.categoryAllocations.first { $0.categoryId == minor.id })
        #expect(majorAllocation.allocatableAmount == 0)
        #expect(minorAllocation.allocatableAmount == 25000)
    }

    // MARK: - Helper Functions

    private func createTransaction(
        amount: Decimal,
        category: Kakeibo.Category? = nil,
        majorCategory: Kakeibo.Category? = nil,
        minorCategory: Kakeibo.Category? = nil,
        year: Int = 2025,
        month: Int = 11,
    ) -> Transaction {
        Transaction(
            date: Date.from(year: year, month: month) ?? Date(),
            title: "テスト取引",
            amount: amount,
            majorCategory: majorCategory ?? category,
            minorCategory: minorCategory,
        )
    }

    private func makeConfig(
        policy: AnnualBudgetPolicy = .automatic,
        allocations: [AllocationSeed] = [],
    ) -> AnnualBudgetConfig {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 500_000,
            policy: policy,
        )
        config.allocations = allocations.map { seed in
            let allocation = AnnualBudgetAllocation(
                amount: seed.amount,
                category: seed.category,
                policyOverride: seed.override,
            )
            allocation.config = config
            return allocation
        }
        return config
    }
}

private struct AllocationSeed {
    let category: Kakeibo.Category
    let amount: Decimal
    let override: AnnualBudgetPolicy?
}
