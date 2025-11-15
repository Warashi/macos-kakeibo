import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTestsRecurringPaymentSavings {
    @Test("定期支払い積立：月次積立金額の合計を取得")
    internal func recurringPaymentSavings_monthlyTotal() async throws {
        let (store, context) = try await makeStore()

        let category = Category(name: "保険・税金")
        let definition1 = RecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: makeDate(year: 2026, month: 5, day: 1),
            category: category,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = RecurringPaymentDefinition(
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

        await store.refresh()

        // When
        let total = store.monthlyRecurringPaymentSavingsTotal

        // Then
        #expect(total == 9750) // 3750 + 6000
    }

    @Test("定期支払い積立：カテゴリ別積立金額を取得")
    internal func recurringPaymentSavings_byCategory() async throws {
        let (store, context) = try await makeStore()

        let categoryTax = Category(name: "保険・税金")
        let categoryEducation = Category(name: "教育費")

        let definition1 = RecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: makeDate(year: 2026, month: 5, day: 1),
            category: categoryTax,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = RecurringPaymentDefinition(
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

        await store.refresh()

        // When
        let allocations = store.categoryRecurringPaymentSavings

        // Then
        #expect(allocations.count == 2)
        #expect(allocations[categoryTax.id] == 3750)
        #expect(allocations[categoryEducation.id] == 10000)
    }

    @Test("定期支払い積立：積立状況一覧を取得")
    internal func recurringPaymentSavings_entries() async throws {
        let (store, context) = try await makeStore()

        let balanceService = RecurringPaymentBalanceService()

        let definition = RecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: makeDate(year: 2027, month: 3, day: 1),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        // 12ヶ月分の積立を記録
        var balance: RecurringPaymentSavingBalance?
        for month in 1 ... 12 {
            balance = balanceService.recordMonthlySavings(
                params: RecurringPaymentBalanceService.MonthlySavingsParameters(
                    definition: definition,
                    balance: balance,
                    year: 2025,
                    month: month,
                    context: context,
                ),
            )
        }
        try context.save()

        await store.refresh()

        // When
        let entries = store.recurringPaymentSavingsEntries

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

    @Test("定期支払い積立：残高不足の場合アラートフラグが立つ")
    internal func recurringPaymentSavings_alertFlag() async throws {
        let (store, context) = try await makeStore()

        let definition = RecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: makeDate(year: 2027, month: 3, day: 1),
            savingStrategy: .evenlyDistributed,
        )

        let balance = RecurringPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 100_000,
            totalPaidAmount: 120_000, // 超過払い
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(definition)
        context.insert(balance)
        try context.save()

        await store.refresh()

        // When
        let entries = store.recurringPaymentSavingsEntries

        // Then
        let entry = try #require(entries.first)
        #expect(entry.hasAlert) // 残高がマイナスなのでアラート
        #expect(entry.balance == -20000)
    }

    // MARK: - Helpers

    @MainActor
    private func makeStore() async throws -> (BudgetStore, ModelContext) {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = try await makeBudgetStore(context: context)
        store.currentYear = 2025
        store.currentMonth = 11
        return (store, context)
    }

    @DatabaseActor
    private func makeBudgetStore(context: ModelContext) async throws -> BudgetStore {
        let repository = SwiftDataBudgetRepository(modelContext: context)
        let calculator = BudgetCalculator()
        let monthlyUseCase = DefaultMonthlyBudgetUseCase(calculator: calculator)
        let annualUseCase = DefaultAnnualBudgetUseCase()
        let recurringPaymentUseCase = DefaultRecurringPaymentSavingsUseCase(calculator: calculator)
        let mutationUseCase = DefaultBudgetMutationUseCase(repository: repository)

        return await BudgetStore(
            repository: repository,
            monthlyUseCase: monthlyUseCase,
            annualUseCase: annualUseCase,
            recurringPaymentUseCase: recurringPaymentUseCase,
            mutationUseCase: mutationUseCase,
        )
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer.createInMemoryContainer()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Date.from(year: year, month: month, day: day) ?? Date()
    }
}
