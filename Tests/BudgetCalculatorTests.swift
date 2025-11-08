import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct BudgetCalculatorTests {
    private let calculator: BudgetCalculator = BudgetCalculator()

    @Test("単一予算計算：正常ケース")
    internal func singleCalculation_success() throws {
        // Given
        let budgetAmount: Decimal = 100_000
        let actualAmount: Decimal = 80000

        // When
        let result = calculator.calculate(
            budgetAmount: budgetAmount,
            actualAmount: actualAmount,
        )

        // Then
        #expect(result.budgetAmount == budgetAmount)
        #expect(result.actualAmount == actualAmount)
        #expect(result.remainingAmount == 20000)
        #expect(result.usageRate == 0.8)
        #expect(!result.isOverBudget)
    }

    @Test("単一予算計算：予算超過")
    internal func singleCalculation_overBudget() throws {
        // Given
        let budgetAmount: Decimal = 100_000
        let actualAmount: Decimal = 120_000

        // When
        let result = calculator.calculate(
            budgetAmount: budgetAmount,
            actualAmount: actualAmount,
        )

        // Then
        #expect(result.budgetAmount == budgetAmount)
        #expect(result.actualAmount == actualAmount)
        #expect(result.remainingAmount == -20000)
        #expect(result.usageRate == 1.2)
        #expect(result.isOverBudget)
    }

    @Test("単一予算計算：予算額0")
    internal func singleCalculation_zeroBudget() throws {
        // Given
        let budgetAmount: Decimal = 0
        let actualAmount: Decimal = 50000

        // When
        let result = calculator.calculate(
            budgetAmount: budgetAmount,
            actualAmount: actualAmount,
        )

        // Then
        #expect(result.budgetAmount == budgetAmount)
        #expect(result.actualAmount == actualAmount)
        #expect(result.usageRate == 0.0)
    }

    @Test("月次予算計算：正常ケース")
    internal func monthlyBudget_success() throws {
        // Given
        let category = Category(name: "食費")
        let transactions = createSampleTransactions(category: category)
        let budgets = [
            Budget(amount: 100_000, year: 2025, month: 11), // 全体予算
            Budget(amount: 50000, category: category, year: 2025, month: 11), // カテゴリ別予算
        ]

        // When
        let result = calculator.calculateMonthlyBudget(
            transactions: transactions,
            budgets: budgets,
            year: 2025,
            month: 11,
        )

        // Then
        #expect(result.year == 2025)
        #expect(result.month == 11)
        #expect(result.overallCalculation != nil)
        #expect(!result.categoryCalculations.isEmpty)
    }

    @Test("予算超過チェック")
    internal func willExceedBudgetCheck() throws {
        // Given
        let category = Category(name: "食費")
        let currentExpense: Decimal = 80000
        let budgetAmount: Decimal = 100_000

        // When & Then
        // 超過しないケース
        let willExceed1 = calculator.willExceedBudget(
            category: category,
            amount: 15000,
            currentExpense: currentExpense,
            budgetAmount: budgetAmount,
        )
        #expect(!willExceed1)

        // 超過するケース
        let willExceed2 = calculator.willExceedBudget(
            category: category,
            amount: 25000,
            currentExpense: currentExpense,
            budgetAmount: budgetAmount,
        )
        #expect(willExceed2)
    }

    // MARK: - Helper Methods

    private func createSampleTransactions(category: Category) -> [Transaction] {
        [
            createTransaction(amount: -30000, category: category),
            createTransaction(amount: -20000, category: category),
            createTransaction(amount: -15000, category: category),
        ]
    }

    private func createTransaction(
        amount: Decimal,
        category: Category,
    ) -> Transaction {
        Transaction(
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "テスト取引",
            amount: amount,
            majorCategory: category,
        )
    }
}
