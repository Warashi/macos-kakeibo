import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct RecurringPaymentStoreDeleteDefinitionTests {
    @Test("定義削除：正常系で定義が削除される")
    internal func deleteDefinition_success() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        // 削除前の確認
        var descriptor: ModelFetchRequest<SwiftDataRecurringPaymentDefinition> = ModelFetchFactory.make()
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
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 24)
        let definitionId = definition.id
        let refreshedDefinition = try #require(
            context.fetch(RecurringPaymentQueries.definitions(
                predicate: #Predicate { $0.id == definitionId }
            )).first
        )
        #expect(!refreshedDefinition.occurrences.isEmpty)

        // Occurrence数を記録
        let occurrenceCountBefore = refreshedDefinition.occurrences.count

        try await store.deleteDefinition(definitionId: definition.id)

        // Occurrenceも削除されていることを確認
        let descriptor: ModelFetchRequest<SwiftDataRecurringPaymentOccurrence> = ModelFetchFactory.make()
        let occurrences = try context.fetch(descriptor)
        #expect(occurrences.isEmpty)
        #expect(occurrenceCountBefore > 0) // 削除前には存在していたことを確認
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) async throws -> (RecurringPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await SwiftDataRecurringPaymentRepository(
            modelContainer: container,
            currentDateProvider: { referenceDate },
        )
        let store = RecurringPaymentStore(
            repository: repository,
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
