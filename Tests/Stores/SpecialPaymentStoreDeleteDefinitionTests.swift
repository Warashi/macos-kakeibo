import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentStoreDeleteDefinitionTests {
    @Test("定義削除：正常系で定義が削除される")
    internal func deleteDefinition_success() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

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
        var descriptor: ModelFetchRequest<SpecialPaymentDefinition> = ModelFetchFactory.make()
        var definitions = try context.fetch(descriptor)
        #expect(definitions.count == 1)

        try await store.deleteDefinition(definitionId: definition.id)

        // 削除後の確認
        descriptor = ModelFetchFactory.make()
        definitions = try context.fetch(descriptor)
        #expect(definitions.isEmpty)
    }

    @Test("定義削除：Occurrenceもカスケード削除される")
    internal func deleteDefinition_cascadeDeletesOccurrences() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 24)
        #expect(!definition.occurrences.isEmpty)

        // Occurrence数を記録
        let occurrenceCountBefore = definition.occurrences.count

        try await store.deleteDefinition(definitionId: definition.id)

        // Occurrenceも削除されていることを確認
        let descriptor: ModelFetchRequest<SpecialPaymentOccurrence> = ModelFetchFactory.make()
        let occurrences = try context.fetch(descriptor)
        #expect(occurrences.isEmpty)
        #expect(occurrenceCountBefore > 0) // 削除前には存在していたことを確認
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) async throws -> (SpecialPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await SwiftDataSpecialPaymentRepository(
            modelContext: context,
            currentDateProvider: { referenceDate }
        )
        let store = SpecialPaymentStore(
            repository: repository,
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
