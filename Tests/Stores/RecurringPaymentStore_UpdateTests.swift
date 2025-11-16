import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct RecurringPaymentStoreUpdateTests {
    @Test("実績更新：実績データを更新できる")
    internal func updateOccurrence_updatesActualData() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = RecurringPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.min(by: { $0.scheduledDate < $1.scheduledDate }))

        let actualDate = try #require(Date.from(year: 2025, month: 3, day: 16))
        let input = OccurrenceUpdateInput(
            status: .completed,
            actualDate: actualDate,
            actualAmount: 48000,
            transaction: nil,
        )
        try await store.updateOccurrence(
            occurrenceId: occurrence.id,
            input: input,
        )

        #expect(occurrence.status == .completed)
        #expect(occurrence.actualDate == actualDate)
        #expect(occurrence.actualAmount == 48000)
    }

    @Test("実績更新：completedからplannedに戻すとスケジュール再計算される")
    internal func updateOccurrence_resyncsWhenStatusChangesFromCompleted() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = RecurringPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.min(by: { $0.scheduledDate < $1.scheduledDate }))
        #expect(definition.occurrences.count == 2)

        let actualDate = try #require(Date.from(year: 2025, month: 3, day: 16))
        let completionInput = OccurrenceCompletionInput(
            actualDate: actualDate,
            actualAmount: 50000,
        )
        try await store.markOccurrenceCompleted(
            occurrenceId: occurrence.id,
            input: completionInput,
            horizonMonths: 24,
        )

        let occurrenceCountAfterCompleted = definition.occurrences.count
        #expect(occurrenceCountAfterCompleted == 4)

        let updateInput = OccurrenceUpdateInput(
            status: .planned,
            actualDate: nil,
            actualAmount: nil,
            transaction: nil,
        )
        try await store.updateOccurrence(
            occurrenceId: occurrence.id,
            input: updateInput,
            horizonMonths: 12,
        )

        #expect(occurrence.status == .planned)
        #expect(occurrence.actualDate == nil)
        #expect(occurrence.actualAmount == nil)
        let occurrenceCountAfterReverted = definition.occurrences.count
        #expect(occurrenceCountAfterReverted == 2)
    }

    @Test("実績更新：plannedからcompletedに変更するとスケジュール再計算される")
    internal func updateOccurrence_resyncsWhenStatusChangesToCompleted() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = RecurringPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.min(by: { $0.scheduledDate < $1.scheduledDate }))
        let occurrenceCountBefore = definition.occurrences.count

        let actualDate = try #require(Date.from(year: 2025, month: 3, day: 16))
        let input = OccurrenceUpdateInput(
            status: .completed,
            actualDate: actualDate,
            actualAmount: 48000,
            transaction: nil,
        )
        try await store.updateOccurrence(
            occurrenceId: occurrence.id,
            input: input,
        )

        #expect(occurrence.status == .completed)
        let occurrenceCountAfter = definition.occurrences.count
        #expect(occurrenceCountAfter > occurrenceCountBefore)
    }

    @Test("実績更新：completedのまま実績データだけ変更する場合はスケジュール再計算されない")
    internal func updateOccurrence_noResyncWhenOnlyActualDataChanges() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = RecurringPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.min(by: { $0.scheduledDate < $1.scheduledDate }))

        let actualDate1 = try #require(Date.from(year: 2025, month: 3, day: 16))
        let completionInput = OccurrenceCompletionInput(
            actualDate: actualDate1,
            actualAmount: 50000,
        )
        try await store.markOccurrenceCompleted(
            occurrenceId: occurrence.id,
            input: completionInput,
        )

        let occurrenceCountAfterCompleted = definition.occurrences.count

        let actualDate2 = try #require(Date.from(year: 2025, month: 3, day: 17))
        let updateInput = OccurrenceUpdateInput(
            status: .completed,
            actualDate: actualDate2,
            actualAmount: 48000,
            transaction: nil,
        )
        try await store.updateOccurrence(
            occurrenceId: occurrence.id,
            input: updateInput,
        )

        #expect(occurrence.actualDate == actualDate2)
        #expect(occurrence.actualAmount == 48000)
        #expect(definition.occurrences.count == occurrenceCountAfterCompleted)
    }

    @Test("実績更新：バリデーションエラー（完了状態で実績日なし）")
    internal func updateOccurrence_validationError_completedWithoutActualDate() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = RecurringPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.first)

        await #expect(throws: RecurringPaymentDomainError.self) {
            let input = OccurrenceUpdateInput(
                status: .completed,
                actualDate: nil,
                actualAmount: 50000,
                transaction: nil,
            )
            try await store.updateOccurrence(
                occurrenceId: occurrence.id,
                input: input,
            )
        }
    }

    @Test("実績更新：実績日が予定日から90日以上ずれている場合の警告")
    internal func updateOccurrence_validationWarning_actualDateTooFarFromScheduled() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let scheduledDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = RecurringPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: scheduledDate,
        )
        context.insert(definition)
        try context.save()

        try await store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.first)

        let farActualDate = try #require(Date.from(year: 2025, month: 7, day: 1))

        await #expect(throws: RecurringPaymentDomainError.self) {
            let input = OccurrenceUpdateInput(
                status: .completed,
                actualDate: farActualDate,
                actualAmount: 50000,
                transaction: nil,
            )
            try await store.updateOccurrence(
                occurrenceId: occurrence.id,
                input: input,
            )
        }
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) async throws -> (RecurringPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await SwiftDataRecurringPaymentRepository(
            modelContainer: container,
            currentDateProvider: { referenceDate },
            sharedContext: context
        )
        let store = RecurringPaymentStore(
            repository: repository,
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
