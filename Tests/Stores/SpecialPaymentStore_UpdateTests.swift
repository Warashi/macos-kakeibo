import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentStoreUpdateTests {
    @Test("実績更新：実績データを更新できる")
    internal func updateOccurrence_updatesActualData() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(for: definition, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.first)

        let actualDate = try #require(Date.from(year: 2025, month: 3, day: 16))
        let input = OccurrenceUpdateInput(
            status: .completed,
            actualDate: actualDate,
            actualAmount: 48000,
            transaction: nil,
        )
        try store.updateOccurrence(
            occurrence,
            input: input,
        )

        #expect(occurrence.status == .completed)
        #expect(occurrence.actualDate == actualDate)
        #expect(occurrence.actualAmount == 48000)
    }

    @Test("実績更新：completedからplannedに戻すとスケジュール再計算される")
    internal func updateOccurrence_resyncsWhenStatusChangesFromCompleted() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(for: definition, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.first)
        #expect(definition.occurrences.count == 2)

        let actualDate = try #require(Date.from(year: 2025, month: 3, day: 16))
        let completionInput = OccurrenceCompletionInput(
            actualDate: actualDate,
            actualAmount: 50000,
        )
        try store.markOccurrenceCompleted(
            occurrence,
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
        try store.updateOccurrence(
            occurrence,
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
    internal func updateOccurrence_resyncsWhenStatusChangesToCompleted() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(for: definition, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.first)
        let occurrenceCountBefore = definition.occurrences.count

        let actualDate = try #require(Date.from(year: 2025, month: 3, day: 16))
        let input = OccurrenceUpdateInput(
            status: .completed,
            actualDate: actualDate,
            actualAmount: 48000,
            transaction: nil,
        )
        try store.updateOccurrence(
            occurrence,
            input: input,
        )

        #expect(occurrence.status == .completed)
        let occurrenceCountAfter = definition.occurrences.count
        #expect(occurrenceCountAfter > occurrenceCountBefore)
    }

    @Test("実績更新：completedのまま実績データだけ変更する場合はスケジュール再計算されない")
    internal func updateOccurrence_noResyncWhenOnlyActualDataChanges() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(for: definition, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.first)

        let actualDate1 = try #require(Date.from(year: 2025, month: 3, day: 16))
        let completionInput = OccurrenceCompletionInput(
            actualDate: actualDate1,
            actualAmount: 50000,
        )
        try store.markOccurrenceCompleted(
            occurrence,
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
        try store.updateOccurrence(
            occurrence,
            input: updateInput,
        )

        #expect(occurrence.actualDate == actualDate2)
        #expect(occurrence.actualAmount == 48000)
        #expect(definition.occurrences.count == occurrenceCountAfterCompleted)
    }

    @Test("実績更新：バリデーションエラー（完了状態で実績日なし）")
    internal func updateOccurrence_validationError_completedWithoutActualDate() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(for: definition, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.first)

        #expect(throws: SpecialPaymentDomainError.self) {
            let input = OccurrenceUpdateInput(
                status: .completed,
                actualDate: nil,
                actualAmount: 50000,
                transaction: nil,
            )
            try store.updateOccurrence(
                occurrence,
                input: input,
            )
        }
    }

    @Test("実績更新：実績日が予定日から90日以上ずれている場合の警告")
    internal func updateOccurrence_validationWarning_actualDateTooFarFromScheduled() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let scheduledDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: scheduledDate,
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(for: definition, horizonMonths: 12)
        let occurrence = try #require(definition.occurrences.first)

        let farActualDate = try #require(Date.from(year: 2025, month: 7, day: 1))

        #expect(throws: SpecialPaymentDomainError.self) {
            let input = OccurrenceUpdateInput(
                status: .completed,
                actualDate: farActualDate,
                actualAmount: 50000,
                transaction: nil,
            )
            try store.updateOccurrence(
                occurrence,
                input: input,
            )
        }
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
