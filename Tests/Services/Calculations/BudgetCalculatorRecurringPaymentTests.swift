import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct BudgetCalculatorRecurringPaymentTests {
    private let calculator: BudgetCalculator = BudgetCalculator()

    // MARK: - 定期支払い積立計算テスト

    @Test("定期支払い積立状況の計算")
    internal func calculateRecurringPaymentSavings_success() throws {
        // Given
        let category = Category(name: "保険・税金")
        let definition1 = RecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
            category: category,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = RecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date.from(year: 2027, month: 3) ?? Date(),
            category: category,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 6000,
        )

        let balance1 = RecurringPaymentSavingBalance(
            definition: definition1,
            totalSavedAmount: 22500,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        let balance2 = RecurringPaymentSavingBalance(
            definition: definition2,
            totalSavedAmount: 60000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        // When
        let results = calculator.calculateRecurringPaymentSavings(
            RecurringPaymentSavingsCalculationInput(
                definitions: [
                    RecurringPaymentDefinitionDTO(from: definition1),
                    RecurringPaymentDefinitionDTO(from: definition2),
                ],
                balances: [
                    RecurringPaymentSavingBalanceDTO(from: balance1),
                    RecurringPaymentSavingBalanceDTO(from: balance2),
                ],
                occurrences: [],
                year: 2025,
                month: 11,
            ),
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

    @Test("定期支払い積立状況の計算：残高がない場合")
    internal func calculateRecurringPaymentSavings_noBalance() throws {
        // Given
        let definition = RecurringPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 4) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )

        // When
        let results = calculator.calculateRecurringPaymentSavings(
            RecurringPaymentSavingsCalculationInput(
                definitions: [RecurringPaymentDefinitionDTO(from: definition)],
                balances: [], // 残高なし
                occurrences: [],
                year: 2025,
                month: 11,
            ),
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
        let definition1 = RecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = RecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date(),
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 6000,
        )
        let definition3 = RecurringPaymentDefinition(
            name: "一時金（積立なし）",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            savingStrategy: .disabled, // 積立無効
        )

        // When
        let total = calculator.calculateMonthlySavingsAllocation(
            definitions: [
                RecurringPaymentDefinitionDTO(from: definition1),
                RecurringPaymentDefinitionDTO(from: definition2),
                RecurringPaymentDefinitionDTO(from: definition3),
            ],
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

        let definition1 = RecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            category: category1,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = RecurringPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            category: category1,
            savingStrategy: .evenlyDistributed,
        )
        let definition3 = RecurringPaymentDefinition(
            name: "学資保険",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            category: category2,
            savingStrategy: .evenlyDistributed,
        )
        let definition4 = RecurringPaymentDefinition(
            name: "カテゴリなし",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            category: nil, // カテゴリなし
            savingStrategy: .evenlyDistributed,
        )

        // When
        let allocations = calculator.calculateCategorySavingsAllocation(
            definitions: [
                RecurringPaymentDefinitionDTO(from: definition1),
                RecurringPaymentDefinitionDTO(from: definition2),
                RecurringPaymentDefinitionDTO(from: definition3),
                RecurringPaymentDefinitionDTO(from: definition4),
            ],
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
