import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct AnnualBudgetAllocatorUsageTests {
    private let allocator: AnnualBudgetAllocator = AnnualBudgetAllocator()

    @Test("年次特別枠使用状況計算：自動充当")
    internal func annualBudgetUsage_automatic() throws {
        // Given
        let category = Category(name: "食費", allowsAnnualBudget: true)
        let transactions = createSampleTransactions(category: category)
        let budgets = [
            Budget(amount: 30000, category: category, year: 2025, month: 11),
        ]
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 500_000,
            policy: .automatic,
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateAnnualBudgetUsage(
            params: params,
            upToMonth: 11,
        )

        // Then
        #expect(result.year == 2025)
        #expect(result.totalAmount == 500_000)
        #expect(result.usedAmount == 50000)
        #expect(result.remainingAmount == 450_000)
        #expect(result.usageRate == 0.1)
    }

    @Test("月次充当計算：年次特別枠使用状況が正しく計算される")
    internal func monthlyAllocation_includesAnnualUsage() throws {
        // Given
        let category = Category(name: "食費", allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -80000, category: category),
        ]
        let budgets = [
            Budget(amount: 50000, category: category, year: 2025, month: 11),
        ]
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 500_000,
            policy: .automatic,
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        #expect(result.annualBudgetUsage.usedAmount == 30000)
        #expect(result.annualBudgetUsage.remainingAmount == 470_000)
    }
}

private func createSampleTransactions(category: Kakeibo.Category) -> [Transaction] {
    [
        createTransaction(amount: -50000, category: category),
        createTransaction(amount: -30000, category: category),
    ]
}

private func createTransaction(
    amount: Decimal,
    category: Kakeibo.Category,
    minorCategory: Kakeibo.Category? = nil,
) -> Transaction {
    createTransaction(
        amount: amount,
        majorCategory: category,
        minorCategory: minorCategory,
    )
}

private func createTransaction(
    amount: Decimal,
    majorCategory: Kakeibo.Category?,
    minorCategory: Kakeibo.Category? = nil,
) -> Transaction {
    Transaction(
        date: Date.from(year: 2025, month: 11) ?? Date(),
        title: "テスト取引",
        amount: amount,
        majorCategory: majorCategory,
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

private struct AllocationSeed {
    let category: Kakeibo.Category
    let amount: Decimal
    let override: AnnualBudgetPolicy?
}

@Suite(.serialized)
internal struct BudgetAllocatorMonthlyTests {
    private let allocator: AnnualBudgetAllocator = AnnualBudgetAllocator()

    @Test("年次特別枠使用状況計算：無効")
    internal func annualBudgetUsage_disabled() throws {
        // Given
        let category = Category(name: "食費", allowsAnnualBudget: true)
        let transactions = createSampleTransactions(category: category)
        let budgets = [
            Budget(amount: 30000, category: category, year: 2025, month: 11),
        ]
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 500_000,
            policy: .disabled,
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateAnnualBudgetUsage(
            params: params,
            upToMonth: 11,
        )

        // Then
        #expect(result.year == 2025)
        #expect(result.totalAmount == 500_000)
        #expect(result.usedAmount == 0)
        #expect(result.remainingAmount == 500_000)
        #expect(result.usageRate == 0.0)
    }

    @Test("月次充当計算：予算超過なし")
    internal func monthlyAllocation_noBudgetExcess() throws {
        // Given
        let category = Category(name: "食費", allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -20000, category: category),
        ]
        let budgets = [
            Budget(amount: 50000, category: category, year: 2025, month: 11),
        ]
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 500_000,
            policy: .automatic,
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        #expect(result.year == 2025)
        #expect(result.month == 11)
        // 予算超過がないので、充当額は0
        #expect(result.categoryAllocations.allSatisfy { $0.allocatableAmount == 0 })
    }

    @Test("月次充当計算：予算超過あり")
    internal func monthlyAllocation_budgetExceeded() throws {
        // Given
        let category = Category(name: "食費", allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -80000, category: category),
        ]
        let budgets = [
            Budget(amount: 50000, category: category, year: 2025, month: 11),
        ]
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 500_000,
            policy: .automatic,
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        #expect(result.year == 2025)
        #expect(result.month == 11)
        // 予算超過があるので、充当額が設定される
        let foodAllocation = result.categoryAllocations.first { $0.categoryName == category.name }
        #expect(foodAllocation != nil)
        #expect(foodAllocation?.excessAmount == 30000) // 80000 - 50000
        #expect(foodAllocation?.allocatableAmount == 30000) // 自動充当
    }

    @Test("全額年次枠指定カテゴリは実績全体を充当する")
    internal func monthlyAllocation_fullCoverageOverrideUsesActual() throws {
        // Given
        let category = Category(name: "特別", allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -40000, category: category),
        ]
        let budgets = [
            Budget(amount: 50000, category: category, year: 2025, month: 11),
        ]
        let config = makeConfig(
            policy: AnnualBudgetPolicy.manual,
            allocations: [
                AllocationSeed(category: category, amount: 120_000, override: .fullCoverage),
            ],
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        guard let specialAllocation = result.categoryAllocations.first else {
            Issue.record()
            return
        }
        #expect(specialAllocation.annualBudgetAmount == 120_000)
        #expect(specialAllocation.allocatableAmount == 40000)
        #expect(specialAllocation.excessAmount == 40000)
        #expect(specialAllocation.monthlyBudgetAmount == 50000)
        #expect(result.annualBudgetUsage.usedAmount == 40000)
    }

    @Test("全額年次枠カテゴリは月次予算がなくても集計される")
    internal func monthlyAllocation_fullCoverageWithoutMonthlyBudget() throws {
        // Given
        let category = Category(name: "旅行", allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -60000, category: category),
        ]
        let budgets: [Budget] = []
        let config = makeConfig(
            allocations: [
                AllocationSeed(category: category, amount: 90000, override: .fullCoverage),
            ],
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        guard let allocation = result.categoryAllocations.first else {
            Issue.record()
            return
        }
        #expect(allocation.annualBudgetAmount == 90000)
        #expect(allocation.monthlyBudgetAmount == 0)
        #expect(allocation.allocatableAmount == 60000)
        #expect(allocation.excessAmount == 60000)
        #expect(result.annualBudgetUsage.usedAmount == 60000)
    }

    @Test("自動充当カテゴリは月次予算がなくても集計される")
    internal func monthlyAllocation_unbudgetedAutomaticCategory() throws {
        // Given
        let category = Category(name: "医療", allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -20000, category: category),
        ]
        let budgets: [Budget] = []
        let config = makeConfig(
            allocations: [
                AllocationSeed(category: category, amount: 150_000, override: nil),
            ],
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        let allocation = try #require(result.categoryAllocations.first)
        #expect(allocation.monthlyBudgetAmount == 0)
        #expect(allocation.actualAmount == 20000)
        #expect(allocation.allocatableAmount == 20000)
        #expect(result.annualBudgetUsage.usedAmount == 20000)
    }

    @Test("全額年次枠の大項目では中項目の支出も集計される")
    internal func monthlyAllocation_fullCoverageMajorIncludesMinors() throws {
        // Given
        let major = Category(name: "特別費", allowsAnnualBudget: true)
        let minor = Category(name: "旅行", parent: major, allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -25000, category: major, minorCategory: minor),
        ]
        let config = makeConfig(
            allocations: [
                AllocationSeed(category: major, amount: 80000, override: .fullCoverage),
            ],
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: [],
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        let allocation = try #require(result.categoryAllocations.first)
        #expect(allocation.categoryName == major.name)
        #expect(allocation.annualBudgetAmount == 80000)
        #expect(allocation.allocatableAmount == 25000)
        #expect(result.annualBudgetUsage.usedAmount == 25000)
    }

    @Test("取引が中項目のみを持つ場合でも大項目の全額枠に反映される")
    internal func monthlyAllocation_fullCoverageMajorIncludesMinorsWithoutMajorAssignment() throws {
        // Given
        let major = Category(name: "特別費", allowsAnnualBudget: true)
        let minor = Category(name: "旅行", parent: major, allowsAnnualBudget: true)
        let transactions = [
            createTransaction(amount: -18000, majorCategory: nil, minorCategory: minor),
        ]
        let config = makeConfig(
            allocations: [
                AllocationSeed(category: major, amount: 80000, override: .fullCoverage),
            ],
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: [],
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        let allocation = try #require(result.categoryAllocations.first)
        #expect(allocation.categoryName == major.name)
        #expect(allocation.annualBudgetAmount == 80000)
        #expect(allocation.allocatableAmount == 18000)
        #expect(result.annualBudgetUsage.usedAmount == 18000)
    }

    @Test("月次充当計算：年次特別枠使用不可カテゴリ")
    internal func monthlyAllocation_categoryNotAllowed() throws {
        // Given
        let category = Category(name: "食費", allowsAnnualBudget: false)
        let transactions = [
            createTransaction(amount: -80000, category: category),
        ]
        let budgets = [
            Budget(amount: 50000, category: category, year: 2025, month: 11),
        ]
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 500_000,
            policy: .automatic,
        )

        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
        )

        // When
        let result = allocator.calculateMonthlyAllocation(
            params: params,
            year: 2025,
            month: 11,
        )

        // Then
        #expect(result.categoryAllocations.isEmpty)
    }
}
