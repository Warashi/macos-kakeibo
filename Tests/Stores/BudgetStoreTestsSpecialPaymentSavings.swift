import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTestsSpecialPaymentSavings {
    @Test("特別支払い積立：月次積立金額の合計を取得")
    internal func specialPaymentSavings_monthlyTotal() throws {
        let (store, context) = try makeStore()

        let category = Category(name: "保険・税金")
        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: makeDate(year: 2026, month: 5, day: 1),
            category: category,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: makeDate(year: 2027, month: 3, day: 1),
            category: category,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 6000,
        )

        context.insert(category)
        context.insert(definition1)
        context.insert(definition2)
        try context.save()

        // When
        let total = store.monthlySpecialPaymentSavingsTotal

        // Then
        #expect(total == 9750) // 3750 + 6000
    }

    @Test("特別支払い積立：カテゴリ別積立金額を取得")
    internal func specialPaymentSavings_byCategory() throws {
        let (store, context) = try makeStore()

        let categoryTax = Category(name: "保険・税金")
        let categoryEducation = Category(name: "教育費")

        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: makeDate(year: 2026, month: 5, day: 1),
            category: categoryTax,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = SpecialPaymentDefinition(
            name: "学資保険",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: makeDate(year: 2026, month: 3, day: 1),
            category: categoryEducation,
            savingStrategy: .evenlyDistributed,
        )

        context.insert(categoryTax)
        context.insert(categoryEducation)
        context.insert(definition1)
        context.insert(definition2)
        try context.save()

        // When
        let allocations = store.categorySpecialPaymentSavings

        // Then
        #expect(allocations.count == 2)
        #expect(allocations[categoryTax.id] == 3750)
        #expect(allocations[categoryEducation.id] == 10000)
    }

    @Test("特別支払い積立：積立状況一覧を取得")
    internal func specialPaymentSavings_entries() throws {
        let (store, context) = try makeStore()

        let balanceService = SpecialPaymentBalanceService()

        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: makeDate(year: 2027, month: 3, day: 1),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        // 12ヶ月分の積立を記録
        var balance: SpecialPaymentSavingBalance?
        for month in 1 ... 12 {
            balance = balanceService.recordMonthlySavings(
                for: definition,
                balance: balance,
                year: 2025,
                month: month,
                context: context,
            )
        }
        try context.save()

        // When
        let entries = store.specialPaymentSavingsEntries

        // Then
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.name == "車検")
        #expect(entry.monthlySaving == 5000)
        #expect(entry.balance == 60000) // 5000 × 12
        #expect(!entry.hasAlert)
        #expect(entry.progress >= 0)
        #expect(entry.progress <= 1.0)
    }

    @Test("特別支払い積立：残高不足の場合アラートフラグが立つ")
    internal func specialPaymentSavings_alertFlag() throws {
        let (store, context) = try makeStore()

        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: makeDate(year: 2027, month: 3, day: 1),
            savingStrategy: .evenlyDistributed,
        )

        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 100_000,
            totalPaidAmount: 120_000, // 超過払い
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(definition)
        context.insert(balance)
        try context.save()

        // When
        let entries = store.specialPaymentSavingsEntries

        // Then
        let entry = try #require(entries.first)
        #expect(entry.hasAlert) // 残高がマイナスなのでアラート
        #expect(entry.balance == -20000)
    }

    // MARK: - Helpers

    private func makeStore() throws -> (BudgetStore, ModelContext) {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = BudgetStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 11
        return (store, context)
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer.createInMemoryContainer()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Date.from(year: year, month: month, day: day) ?? Date()
    }
}
