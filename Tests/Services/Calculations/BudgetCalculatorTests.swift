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

    // MARK: - 特別支払い積立計算テスト

    @Test("特別支払い積立状況の計算")
    internal func calculateSpecialPaymentSavings_success() throws {
        // Given
        let category = Category(name: "保険・税金")
        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
            category: category,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date.from(year: 2027, month: 3) ?? Date(),
            category: category,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 6000,
        )

        let balance1 = SpecialPaymentSavingBalance(
            definition: definition1,
            totalSavedAmount: 22500,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        let balance2 = SpecialPaymentSavingBalance(
            definition: definition2,
            totalSavedAmount: 60000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        // When
        let results = calculator.calculateSpecialPaymentSavings(
            definitions: [definition1, definition2],
            balances: [balance1, balance2],
            year: 2025,
            month: 11,
        )

        // Then
        #expect(results.count == 2)

        let result1 = try #require(results.first { $0.name == "自動車税" })
        #expect(result1.monthlySaving == 3750) // 45000 / 12
        #expect(result1.totalSaved == 22500)
        #expect(result1.totalPaid == 0)
        #expect(result1.balance == 22500)

        let result2 = try #require(results.first { $0.name == "車検" })
        #expect(result2.monthlySaving == 6000) // カスタム金額
        #expect(result2.totalSaved == 60000)
        #expect(result2.totalPaid == 0)
        #expect(result2.balance == 60000)
    }

    @Test("特別支払い積立状況の計算：残高がない場合")
    internal func calculateSpecialPaymentSavings_noBalance() throws {
        // Given
        let definition = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 4) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )

        // When
        let results = calculator.calculateSpecialPaymentSavings(
            definitions: [definition],
            balances: [], // 残高なし
            year: 2025,
            month: 11,
        )

        // Then
        #expect(results.count == 1)
        let result = try #require(results.first)
        #expect(result.totalSaved == 0)
        #expect(result.totalPaid == 0)
        #expect(result.balance == 0)
    }

    @Test("月次積立金額の合計計算")
    internal func calculateMonthlySavingsAllocation_success() throws {
        // Given
        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date(),
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 6000,
        )
        let definition3 = SpecialPaymentDefinition(
            name: "一時金（積立なし）",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            savingStrategy: .disabled, // 積立無効
        )

        // When
        let total = calculator.calculateMonthlySavingsAllocation(
            definitions: [definition1, definition2, definition3],
            year: 2025,
            month: 11,
        )

        // Then
        // 3750（自動車税） + 6000（車検） = 9750（一時金は除外）
        #expect(total == 9750)
    }

    @Test("カテゴリ別積立金額の計算")
    internal func calculateCategorySavingsAllocation_success() throws {
        // Given
        let category1 = Category(name: "保険・税金")
        let category2 = Category(name: "教育費")

        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            category: category1,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            category: category1,
            savingStrategy: .evenlyDistributed,
        )
        let definition3 = SpecialPaymentDefinition(
            name: "学資保険",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            category: category2,
            savingStrategy: .evenlyDistributed,
        )
        let definition4 = SpecialPaymentDefinition(
            name: "カテゴリなし",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            category: nil, // カテゴリなし
            savingStrategy: .evenlyDistributed,
        )

        // When
        let allocations = calculator.calculateCategorySavingsAllocation(
            definitions: [definition1, definition2, definition3, definition4],
            year: 2025,
            month: 11,
        )

        // Then
        #expect(allocations.count == 2)

        let category1Amount = try #require(allocations[category1.id])
        #expect(category1Amount == 16250) // 3750 + 12500

        let category2Amount = try #require(allocations[category2.id])
        #expect(category2Amount == 10000) // 10000

        // カテゴリなしは含まれない
        #expect(allocations.keys.contains { $0 == definition4.id } == false)
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
