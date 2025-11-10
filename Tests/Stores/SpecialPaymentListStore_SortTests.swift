import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentListStoreSortTests {
    @Test("entries: 日付昇順ソート")
    internal func entries_sortByDateAscending() throws {
        let (store, context) = try makeStore()

        let definition = SpecialPaymentDefinition(
            name: "テスト",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence1 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 10000,
            status: .saving,
        )

        let occurrence2 = SpecialPaymentOccurrence(
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
        let entries = store.entries
        #expect(entries.count == 2)
        #expect(entries[0].scheduledDate < entries[1].scheduledDate)
    }

    @Test("entries: 名称昇順ソート")
    internal func entries_sortByNameAscending() throws {
        let (store, context) = try makeStore()

        let definition1 = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date.from(year: 2026, month: 3) ?? Date(),
        )

        let definition2 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        let occurrence1 = SpecialPaymentOccurrence(
            definition: definition1,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 120_000,
            status: .saving,
        )

        let occurrence2 = SpecialPaymentOccurrence(
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
        let entries = store.entries
        #expect(entries.count == 2)
        #expect(entries[0].name == "自動車税")
        #expect(entries[1].name == "車検")
    }

    // MARK: - Helpers

    private func makeStore() throws -> (SpecialPaymentListStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SpecialPaymentListStore(modelContext: context)
        return (store, context)
    }
}
