import Foundation
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct RecurringPaymentOccurrencesServiceTests {
    @Test("同期で不正な周期を検出する")
    internal func synchronizeValidatesRecurrence() async throws {
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "不正定義",
            amount: 10000,
            recurrenceIntervalMonths: 0,
            firstOccurrenceDate: Date(),
        )
        let repository = InMemoryRecurringPaymentRepository(definitions: [definition])
        let service = RecurringPaymentOccurrencesServiceImpl(repository: repository)

        await #expect(throws: RecurringPaymentDomainError.invalidRecurrence) {
            try await service.synchronizeOccurrences(
                definitionId: definition.id,
                horizonMonths: 12,
                referenceDate: nil,
            )
        }
    }

    @Test("完了処理でOccurrenceが更新され再同期が走る")
    internal func markOccurrenceCompletedUpdatesModel() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 3, day: 1))
        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: SwiftDataRecurringPaymentDefinition(
                name: "引越し費用",
                amount: 200_000,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: referenceDate,
            ),
            scheduledDate: referenceDate,
            expectedAmount: 200_000,
            status: .saving,
        )
        let definition = occurrence.definition
        definition.occurrences = [occurrence]

        let repository = InMemoryRecurringPaymentRepository(
            definitions: [definition],
            currentDateProvider: { referenceDate },
        )
        let service = RecurringPaymentOccurrencesServiceImpl(repository: repository)

        let result = try await service.markOccurrenceCompleted(
            occurrenceId: occurrence.id,
            input: OccurrenceCompletionInput(
                actualDate: referenceDate,
                actualAmount: 210_000,
                transaction: nil,
            ),
            horizonMonths: 12,
        )

        #expect(result.createdCount >= 0)
        #expect(occurrence.status == .completed)
        #expect(occurrence.actualAmount == 210_000)
    }

    @Test("updateOccurrenceはステータスが変わらなければ同期をスキップする")
    internal func updateOccurrenceSkipsSyncWhenStatusUnchanged() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 7, day: 15))
        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: SwiftDataRecurringPaymentDefinition(
                name: "車検",
                amount: 110_000,
                recurrenceIntervalMonths: 24,
                firstOccurrenceDate: referenceDate,
            ),
            scheduledDate: referenceDate,
            expectedAmount: 110_000,
            status: .planned,
        )
        let definition = occurrence.definition
        definition.occurrences = [occurrence]

        let repository = InMemoryRecurringPaymentRepository(
            definitions: [definition],
            currentDateProvider: { referenceDate },
        )
        let service = RecurringPaymentOccurrencesServiceImpl(repository: repository)

        let summary = try await service.updateOccurrence(
            occurrenceId: occurrence.id,
            input: OccurrenceUpdateInput(
                status: .planned,
                actualDate: nil,
                actualAmount: nil,
                transaction: nil,
            ),
            horizonMonths: 6,
        )

        #expect(summary == nil)
        #expect(occurrence.status == .planned)
    }
}
