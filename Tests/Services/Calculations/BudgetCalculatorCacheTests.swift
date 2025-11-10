import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite
internal struct BudgetCalculatorCacheTests {
    @Test("月次予算計算は二度目の呼び出しでキャッシュを利用する")
    internal func monthlyBudgetCachesResult() throws {
        let calculator = BudgetCalculator()
        let category = Category(name: "食費", allowsAnnualBudget: true)
        let budget = Budget(amount: 50_000, category: category, year: 2025, month: 1)
        let transaction = Transaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "ランチ",
            amount: -30_000,
            majorCategory: category
        )

        _ = calculator.calculateMonthlyBudget(
            transactions: [transaction],
            budgets: [budget],
            year: 2025,
            month: 1
        )
        _ = calculator.calculateMonthlyBudget(
            transactions: [transaction],
            budgets: [budget],
            year: 2025,
            month: 1
        )

        let metrics = calculator.cacheMetrics()
        #expect(metrics.monthlyBudgetHits == 1)
        #expect(metrics.monthlyBudgetMisses == 1)
    }

    @Test("取引の更新で月次予算キャッシュが無効化される")
    internal func monthlyBudgetInvalidatesOnTransactionChange() throws {
        let calculator = BudgetCalculator()
        let category = Category(name: "日用品")
        let budget = Budget(amount: 40_000, category: category, year: 2025, month: 2)
        let transaction = Transaction(
            date: Date.from(year: 2025, month: 2) ?? Date(),
            title: "雑貨",
            amount: -10_000,
            majorCategory: category
        )

        _ = calculator.calculateMonthlyBudget(
            transactions: [transaction],
            budgets: [budget],
            year: 2025,
            month: 2
        )
        _ = calculator.calculateMonthlyBudget(
            transactions: [transaction],
            budgets: [budget],
            year: 2025,
            month: 2
        )

        transaction.updatedAt = Date().addingTimeInterval(60)
        _ = calculator.calculateMonthlyBudget(
            transactions: [transaction],
            budgets: [budget],
            year: 2025,
            month: 2
        )

        let metrics = calculator.cacheMetrics()
        #expect(metrics.monthlyBudgetMisses == 2)
    }

    @Test("特別支払い積立計算のキャッシュヒットを測定する")
    internal func specialPaymentSavingsCaching() throws {
        let calculator = BudgetCalculator()
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 60_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 5) ?? Date()
        )
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 20_000,
            totalPaidAmount: 10_000,
            lastUpdatedYear: 2024,
            lastUpdatedMonth: 12
        )

        _ = calculator.calculateSpecialPaymentSavings(
            definitions: [definition],
            balances: [balance],
            year: 2025,
            month: 4
        )
        _ = calculator.calculateSpecialPaymentSavings(
            definitions: [definition],
            balances: [balance],
            year: 2025,
            month: 4
        )

        let metrics = calculator.cacheMetrics()
        #expect(metrics.specialPaymentHits == 1)
        #expect(metrics.specialPaymentMisses == 1)
    }

    @Test("残高更新で特別支払いキャッシュが失効する")
    internal func specialPaymentSavingsInvalidatesOnBalanceChange() throws {
        let calculator = BudgetCalculator()
        let definition = SpecialPaymentDefinition(
            name: "家財保険",
            amount: 36_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date()
        )
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 12_000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2024,
            lastUpdatedMonth: 12
        )

        _ = calculator.calculateSpecialPaymentSavings(
            definitions: [definition],
            balances: [balance],
            year: 2025,
            month: 1
        )

        balance.updatedAt = Date().addingTimeInterval(120)

        _ = calculator.calculateSpecialPaymentSavings(
            definitions: [definition],
            balances: [balance],
            year: 2025,
            month: 1
        )

        let metrics = calculator.cacheMetrics()
        #expect(metrics.specialPaymentMisses == 2)
    }
}
