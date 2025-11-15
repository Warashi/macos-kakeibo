import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct RecurringPaymentStoreTests {
    @Test("同期処理：将来のOccurrenceを生成しリードタイムでステータスを切り替える")
    internal func synchronizeOccurrences_generatesPlannedAndSaving() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 3, day: 20))
        let definition = RecurringPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
            leadTimeMonths: 3,
        )

        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 24)

        #expect(definition.occurrences.count == 2)
        let first = try #require(definition.occurrences.first)
        let second = try #require(definition.occurrences.last)

        #expect(first.scheduledDate.month == 3)
        #expect(first.status == .saving)
        #expect(second.status == .planned)
        #expect(second.expectedAmount == 150_000)
    }

    @Test("同期処理：定義変更時に日付と金額を差分更新する")
    internal func synchronizeOccurrences_updatesWhenDefinitionChanges() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let definition = RecurringPaymentDefinition(
            name: "学資保険",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: referenceDate,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 18)
        #expect(definition.occurrences.count == 2)

        definition.recurrenceIntervalMonths = 6
        definition.amount = 240_000

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 18)

        #expect(definition.occurrences.count == 4)
        #expect(definition.occurrences.allSatisfy { $0.expectedAmount == 240_000 })
        let intervalMonths = zip(definition.occurrences, definition.occurrences.dropFirst())
            .map { current, next in
                current.scheduledDate.monthsBetween(next.scheduledDate)
            }
        #expect(intervalMonths.allSatisfy { $0 == 6 })
    }

    @Test("実績登録：完了処理で次回スケジュールを繰り上げる")
    internal func markOccurrenceCompleted_advancesSchedule() async throws {
        let referenceDate = try #require(Date.from(year: 2024, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2024, month: 1, day: 15))
        let definition = RecurringPaymentDefinition(
            name: "車検",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 36)
        let occurrence = try #require(definition.occurrences.min(by: { $0.scheduledDate < $1.scheduledDate }))

        let actualDate = try #require(Date.from(year: 2024, month: 1, day: 16))
        let input = OccurrenceCompletionInput(
            actualDate: actualDate,
            actualAmount: 98000,
        )
        try await store.markOccurrenceCompleted(
            occurrenceId: occurrence.id,
            input: input,
        )

        #expect(occurrence.status == .completed)
        #expect(occurrence.actualAmount == 98000)
        #expect(definition.occurrences.contains { $0.scheduledDate.year == 2025 })
        #expect(definition.occurrences.contains { $0.scheduledDate.year == 2026 })
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) async throws -> (RecurringPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await SwiftDataRecurringPaymentRepository(
            modelContext: context,
            currentDateProvider: { referenceDate },
        )
        let store = RecurringPaymentStore(
            repository: repository,
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
