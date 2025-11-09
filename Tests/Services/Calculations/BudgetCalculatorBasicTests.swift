import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct BudgetCalculatorBasicTests {
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

    @Test("期間予算は対象月の計算に含まれる")
    internal func monthlyBudget_includesSpanningBudget() throws {
        let category = Category(name: "食費")
        let transactions = createSampleTransactions(category: category)
        let budgets = [
            Budget(
                amount: 80000,
                startYear: 2025,
                startMonth: 10,
                endYear: 2026,
                endMonth: 1,
            ),
        ]

        let result = calculator.calculateMonthlyBudget(
            transactions: transactions,
            budgets: budgets,
            year: 2025,
            month: 11,
        )

        let overall = try #require(result.overallCalculation)
        #expect(overall.budgetAmount == 80000)
    }

    @Test("全額年次枠カテゴリは全体予算実績から除外される")
    internal func monthlyBudget_excludesFullCoverageCategoriesFromOverall() throws {
        let special = Category(name: "特別費", allowsAnnualBudget: true)
        let travel = Category(name: "旅行", parent: special, allowsAnnualBudget: true)
        let general = Category(name: "食費")

        let transactions = [
            createTransaction(amount: -20000, majorCategory: special),
            createTransaction(amount: -15000, majorCategory: special, minorCategory: travel),
            createTransaction(amount: -10000, category: general),
        ]

        let budgets = [
            Budget(amount: 100_000, year: 2025, month: 11),
        ]

        let excludedIds: Set<UUID> = [special.id, travel.id]

        let result = calculator.calculateMonthlyBudget(
            transactions: transactions,
            budgets: budgets,
            year: 2025,
            month: 11,
            excludedCategoryIds: excludedIds,
        )

        let overall = try #require(result.overallCalculation)
        #expect(overall.actualAmount == 10000)
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

    @Test("大項目予算は子カテゴリ（中項目）の取引も集計する")
    internal func majorCategoryBudget_includesMinorCategoryTransactions() throws {
        // Given: 大項目「食費」と中項目「外食」を作成
        let majorCategory = Category(name: "食費")
        let minorCategory = Category(name: "外食", parent: majorCategory)
        majorCategory.addChild(minorCategory)

        // 取引：大項目のみの取引と中項目を持つ取引を混在
        let transactions: [Transaction] = [
            // 大項目のみの取引（食費）
            createTransaction(amount: -10000, majorCategory: majorCategory, minorCategory: nil),
            // 中項目を持つ取引（食費＞外食）
            createTransaction(amount: -20000, majorCategory: majorCategory, minorCategory: minorCategory),
            createTransaction(amount: -15000, majorCategory: majorCategory, minorCategory: minorCategory),
        ]

        // 予算：大項目「食費」に対して50,000円
        let budgets = [
            Budget(amount: 50000, category: majorCategory, year: 2025, month: 11),
        ]

        // When: 月次予算計算を実行
        let result = calculator.calculateMonthlyBudget(
            transactions: transactions,
            budgets: budgets,
            year: 2025,
            month: 11,
        )

        // Then: 大項目の予算には、大項目のみの取引と中項目を持つ取引の両方が含まれるべき
        let categoryCalc = try #require(result.categoryCalculations.first { $0.categoryId == majorCategory.id })
        #expect(categoryCalc.calculation.actualAmount == 45000) // 10,000 + 20,000 + 15,000
        #expect(categoryCalc.calculation.budgetAmount == 50000)
        #expect(categoryCalc.calculation.remainingAmount == 5000)
    }

    // MARK: - Helper Methods

    private func createSampleTransactions(category: Kakeibo.Category) -> [Transaction] {
        [
            createTransaction(amount: -30000, category: category),
            createTransaction(amount: -20000, category: category),
            createTransaction(amount: -15000, category: category),
        ]
    }

    private func createTransaction(
        amount: Decimal,
        category: Kakeibo.Category
    ) -> Transaction {
        createTransaction(amount: amount, majorCategory: category)
    }

    private func createTransaction(
        amount: Decimal,
        majorCategory: Kakeibo.Category?,
        minorCategory: Kakeibo.Category? = nil
    ) -> Transaction {
        Transaction(
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "テスト取引",
            amount: amount,
            majorCategory: majorCategory,
            minorCategory: minorCategory,
        )
    }

    private func createTransaction(
        amount: Decimal,
        majorCategory: Kakeibo.Category,
        minorCategory: Kakeibo.Category?,
    ) -> Transaction {
        Transaction(
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "テスト取引",
            amount: amount,
            majorCategory: majorCategory,
            minorCategory: minorCategory,
        )
    }
}
