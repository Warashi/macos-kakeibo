import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct AnnualBudgetAllocatorTests {
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

    // MARK: - Helper Methods

    private func createSampleTransactions(category: Kakeibo.Category) -> [Transaction] {
        [
            createTransaction(amount: -50000, category: category),
            createTransaction(amount: -30000, category: category),
        ]
    }

    private func createTransaction(
        amount: Decimal,
        category: Kakeibo.Category,
    ) -> Transaction {
        Transaction(
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "テスト取引",
            amount: amount,
            majorCategory: category,
        )
    }
}
