import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct BudgetCalculatorCacheTests {
    @Test("月次予算計算は二度目の呼び出しでキャッシュを利用する")
    internal func monthlyBudgetCachesResult() throws {
        let calculator = BudgetCalculator()
        let category = DomainFixtures.category(name: "食費", allowsAnnualBudget: true)
        let budget = DomainFixtures.budget(amount: 50000, category: category, startYear: 2025, startMonth: 1)
        let transaction = DomainFixtures.transaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "ランチ",
            amount: -30000,
            majorCategory: category,
        )

        let input = BudgetCalculator.MonthlyBudgetInput(
            transactions: [transaction],
            budgets: [budget],
            categories: [category],
            year: 2025,
            month: 1,
            filter: .default,
            excludedCategoryIds: [],
        )

        _ = calculator.calculateMonthlyBudget(input: input)
        _ = calculator.calculateMonthlyBudget(input: input)

        let metrics = calculator.cacheMetrics()
        #expect(metrics.monthlyBudgetHits == 1)
        #expect(metrics.monthlyBudgetMisses == 1)
    }

    @Test("取引の更新で月次予算キャッシュが無効化される")
    internal func monthlyBudgetInvalidatesOnTransactionChange() throws {
        let calculator = BudgetCalculator()
        let category = DomainFixtures.category(name: "日用品")
        let budget = DomainFixtures.budget(amount: 40000, category: category, startYear: 2025, startMonth: 2)
        let transaction = DomainFixtures.transaction(
            date: Date.from(year: 2025, month: 2) ?? Date(),
            title: "雑貨",
            amount: -10000,
            majorCategory: category,
        )

        let input1 = BudgetCalculator.MonthlyBudgetInput(
            transactions: [transaction],
            budgets: [budget],
            categories: [category],
            year: 2025,
            month: 2,
            filter: .default,
            excludedCategoryIds: [],
        )

        _ = calculator.calculateMonthlyBudget(input: input1)
        _ = calculator.calculateMonthlyBudget(input: input1)

        let updatedTransaction = DomainFixtures.transaction(
            id: transaction.id,
            date: transaction.date,
            title: transaction.title,
            amount: transaction.amount,
            majorCategory: category,
            createdAt: transaction.createdAt,
            updatedAt: Date().addingTimeInterval(60),
        )

        let input2 = BudgetCalculator.MonthlyBudgetInput(
            transactions: [updatedTransaction],
            budgets: [budget],
            categories: [category],
            year: 2025,
            month: 2,
            filter: .default,
            excludedCategoryIds: [],
        )

        _ = calculator.calculateMonthlyBudget(input: input2)

        let metrics = calculator.cacheMetrics()
        #expect(metrics.monthlyBudgetMisses == 2)
    }

    @Test("定期支払い積立計算のキャッシュヒットを測定する")
    internal func recurringPaymentSavingsCaching() throws {
        let calculator = BudgetCalculator()
        let definition = DomainFixtures.recurringPaymentDefinition(
            name: "自動車税",
            amount: 60000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 5) ?? Date(),
        )
        let balance = DomainFixtures.recurringPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 20000,
            totalPaidAmount: 10000,
            lastUpdatedYear: 2024,
            lastUpdatedMonth: 12,
        )

        let input = RecurringPaymentSavingsCalculationInput(
            definitions: [definition],
            balances: [balance],
            occurrences: [],
            year: 2025,
            month: 4,
        )

        _ = calculator.calculateRecurringPaymentSavings(input)
        _ = calculator.calculateRecurringPaymentSavings(input)

        let metrics = calculator.cacheMetrics()
        #expect(metrics.recurringPaymentHits == 1)
        #expect(metrics.recurringPaymentMisses == 1)
    }

    @Test("残高更新で定期支払いキャッシュが失効する")
    internal func recurringPaymentSavingsInvalidatesOnBalanceChange() throws {
        let calculator = BudgetCalculator()
        let definition = DomainFixtures.recurringPaymentDefinition(
            name: "家財保険",
            amount: 36000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date(),
        )
        let balance = DomainFixtures.recurringPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 12000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2024,
            lastUpdatedMonth: 12,
        )

        let input1 = RecurringPaymentSavingsCalculationInput(
            definitions: [definition],
            balances: [balance],
            occurrences: [],
            year: 2025,
            month: 1,
        )

        _ = calculator.calculateRecurringPaymentSavings(input1)

        let updatedBalance = DomainFixtures.recurringPaymentSavingBalance(
            id: balance.id,
            definition: definition,
            totalSavedAmount: balance.totalSavedAmount,
            totalPaidAmount: balance.totalPaidAmount,
            lastUpdatedYear: balance.lastUpdatedYear,
            lastUpdatedMonth: balance.lastUpdatedMonth,
            createdAt: balance.createdAt,
            updatedAt: Date().addingTimeInterval(120),
        )

        let input2 = RecurringPaymentSavingsCalculationInput(
            definitions: [definition],
            balances: [updatedBalance],
            occurrences: [],
            year: 2025,
            month: 1,
        )

        _ = calculator.calculateRecurringPaymentSavings(input2)

        let metrics = calculator.cacheMetrics()
        #expect(metrics.recurringPaymentMisses == 2)
    }
}
