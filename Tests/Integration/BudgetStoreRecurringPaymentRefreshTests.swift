import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("BudgetStore Recurring Payment Refresh")
@MainActor
internal struct BudgetStoreRecurringPaymentRefreshTests {
    @Test("定期支払いを追加するとBudgetStoreが最新の定義と積立額を反映する")
    internal func refreshAfterCreatingRecurringPayment() async throws {
        let (budgetStore, recurringStore) = try await makeStores()
        #expect(budgetStore.recurringPaymentDefinitions.isEmpty)
        #expect(budgetStore.monthlyRecurringPaymentSavingsTotal == 0)

        try await recurringStore.createDefinition(makeInput(name: "自動車税", amount: 120_000, recurrenceMonths: 12))
        await budgetStore.refresh()

        #expect(budgetStore.recurringPaymentDefinitions.count == 1)
        #expect(budgetStore.monthlyRecurringPaymentSavingsTotal == Decimal(10000))
        let entry = try #require(budgetStore.recurringPaymentSavingsEntries.first)
        #expect(entry.name == "自動車税")
        #expect(entry.monthlySaving == Decimal(10000))
    }

    @Test("定期支払いを削除するとBudgetStoreから即時に消える")
    internal func refreshAfterDeletingRecurringPayment() async throws {
        let (budgetStore, recurringStore) = try await makeStores()
        try await recurringStore.createDefinition(makeInput(name: "車検", amount: 60000, recurrenceMonths: 6))
        await budgetStore.refresh()

        let definitionId = try #require(budgetStore.recurringPaymentDefinitions.first?.id)
        try await recurringStore.deleteDefinition(definitionId: definitionId)
        await budgetStore.refresh()

        #expect(budgetStore.recurringPaymentDefinitions.isEmpty)
        #expect(budgetStore.monthlyRecurringPaymentSavingsTotal == 0)
        #expect(budgetStore.recurringPaymentSavingsEntries.isEmpty)
    }

    // MARK: - Helpers

    private func makeStores() async throws -> (BudgetStore, RecurringPaymentStore) {
        let container = try ModelContainer.createInMemoryContainer()
        let budgetStore = await BudgetStackBuilder.makeStore(modelContainer: container)
        budgetStore.currentYear = 2026
        budgetStore.currentMonth = 5
        await budgetStore.refresh()
        let recurringStore = await RecurringPaymentStackBuilder.makeStore(modelContainer: container)
        return (budgetStore, recurringStore)
    }

    private func makeInput(name: String, amount: Decimal, recurrenceMonths: Int) -> RecurringPaymentDefinitionInput {
        RecurringPaymentDefinitionInput(
            name: name,
            amount: amount,
            recurrenceIntervalMonths: recurrenceMonths,
            firstOccurrenceDate: Date.from(year: 2026, month: 5, day: 1) ?? Date(),
            leadTimeMonths: 1,
        )
    }
}
