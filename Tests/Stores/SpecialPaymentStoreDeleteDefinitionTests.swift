import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentStoreDeleteDefinitionTests {
    @Test("定義削除：正常系で定義が削除される")
    internal func deleteDefinition_success() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        // 削除前の確認
        var descriptor = FetchDescriptor<SpecialPaymentDefinition>()
        var definitions = try context.fetch(descriptor)
        #expect(definitions.count == 1)

        try store.deleteDefinition(definition)

        // 削除後の確認
        descriptor = FetchDescriptor<SpecialPaymentDefinition>()
        definitions = try context.fetch(descriptor)
        #expect(definitions.isEmpty)
    }

    @Test("定義削除：Occurrenceもカスケード削除される")
    internal func deleteDefinition_cascadeDeletesOccurrences() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(for: definition, horizonMonths: 24)
        #expect(!definition.occurrences.isEmpty)

        // Occurrence数を記録
        let occurrenceCountBefore = definition.occurrences.count

        try store.deleteDefinition(definition)

        // Occurrenceも削除されていることを確認
        let descriptor = FetchDescriptor<SpecialPaymentOccurrence>()
        let occurrences = try context.fetch(descriptor)
        #expect(occurrences.isEmpty)
        #expect(occurrenceCountBefore > 0) // 削除前には存在していたことを確認
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) throws -> (SpecialPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SpecialPaymentStore(
            modelContext: context,
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
