import Foundation
import Testing

@testable import Kakeibo

@Suite("RecurringPaymentScheduleService Synchronization")
internal struct RecurringPaymentScheduleServiceSyncTests {
    private let service: RecurringPaymentScheduleService = RecurringPaymentScheduleService()

    @Test("定義から将来のOccurrenceを生成する")
    internal func synchronizationPlan_createsFutureOccurrences() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 4, day: 30))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )

        let plan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 24,
        )

        #expect(!plan.created.isEmpty)
        let occurrences = plan.occurrences
        #expect(occurrences.count >= 2)
        let firstOccurrence = try #require(occurrences.first)
        #expect(firstOccurrence.scheduledDate.month == 4)
        #expect(firstOccurrence.scheduledDate.year == 2025)
    }

    @Test("完了済みOccurrenceはロックされ、再生成の対象にならない")
    internal func synchronizationPlan_preservesLockedOccurrences() throws {
        let firstDate = try #require(Date.from(year: 2024, month: 10, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "車検",
            amount: 100_000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )

        let lockedOccurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: firstDate,
            expectedAmount: 100_000,
            status: .completed,
            actualDate: firstDate,
            actualAmount: 100_000,
        )
        definition.occurrences = [lockedOccurrence]

        let plan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 12,
        )

        #expect(plan.locked.contains(where: { $0.id == lockedOccurrence.id }))
        #expect(!plan.created.contains(where: { $0.id == lockedOccurrence.id }))
    }

    @Test("リードタイム条件を満たすとステータスが更新される")
    internal func synchronizationPlan_updatesStatusesWithinLeadTime() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 6, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 4, day: 1))

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "保険料",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
            leadTimeMonths: 3,
        )

        let existingOccurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: firstDate,
            expectedAmount: 50000,
            status: .planned,
        )
        definition.occurrences = [existingOccurrence]

        let plan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 12,
        )

        let occurrence = try #require(plan.occurrences.first { $0.id == existingOccurrence.id })
        #expect(occurrence.status == .saving)
    }
}
