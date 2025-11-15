import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct RecurringPaymentListStoreSortTests {
    @Test("entries: 日付昇順ソート")
    internal func entries_sortByDateAscending() async throws {
        let (store, context) = try await makeStore()

        let definition = RecurringPaymentDefinition(
            name: "テスト",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence1 = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 10000,
            status: .saving,
        )

        let occurrence2 = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 10000,
            status: .saving,
        )

        context.insert(definition)
        context.insert(occurrence1)
        context.insert(occurrence2)
        try context.save()

        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 12) ?? Date()

        // When
        store.sortOrder = .dateAscending

        // Then
        let entries = await store.entries()
        #expect(entries.count == 2)
        #expect(entries[0].scheduledDate < entries[1].scheduledDate)
    }

    @Test("entries: 名称昇順ソート")
    internal func entries_sortByNameAscending() async throws {
        let (store, context) = try await makeStore()

        let definition1 = RecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date.from(year: 2026, month: 3) ?? Date(),
        )

        let definition2 = RecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        let occurrence1 = RecurringPaymentOccurrence(
            definition: definition1,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 120_000,
            status: .saving,
        )

        let occurrence2 = RecurringPaymentOccurrence(
            definition: definition2,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .saving,
        )

        context.insert(definition1)
        context.insert(definition2)
        context.insert(occurrence1)
        context.insert(occurrence2)
        try context.save()

        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 12) ?? Date()

        // When
        store.sortOrder = .nameAscending

        // Then
        let entries = await store.entries()
        #expect(entries.count == 2)
        #expect(entries[0].name == "自動車税")
        #expect(entries[1].name == "車検")
    }

    // MARK: - Helpers

    private func makeStore() async throws -> (RecurringPaymentListStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await RecurringPaymentRepositoryFactory.make(modelContext: context)
        let store = RecurringPaymentListStore(repository: repository)
        return (store, context)
    }
}
