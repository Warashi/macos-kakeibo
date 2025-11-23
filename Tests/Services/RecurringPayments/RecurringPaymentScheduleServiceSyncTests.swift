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
            backfillFromFirstDate: false,
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
            backfillFromFirstDate: false,
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
            backfillFromFirstDate: false,
        )

        let occurrence = try #require(plan.occurrences.first { $0.id == existingOccurrence.id })
        #expect(occurrence.status == .saving)
    }

    @Test("開始日を過去に変更した場合、完了済みOccurrenceより前のOccurrenceが生成される")
    internal func synchronizationPlan_backfillsWhenFirstDateChangedToPast() throws {
        let originalFirstDate = try #require(Date.from(year: 2025, month: 6, day: 1))
        let newFirstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 12, day: 1))

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "月額サブスクリプション",
            amount: 1000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: newFirstDate,
        )

        // 6月と7月のOccurrenceが完了済み
        let completedJune = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: originalFirstDate,
            expectedAmount: 1000,
            status: .completed,
            actualDate: originalFirstDate,
            actualAmount: 1000,
        )
        let julyDate = try #require(Date.from(year: 2025, month: 7, day: 1))
        let completedJuly = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: julyDate,
            expectedAmount: 1000,
            status: .completed,
            actualDate: julyDate,
            actualAmount: 1000,
        )
        definition.occurrences = [completedJune, completedJuly]

        let plan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 12,
            backfillFromFirstDate: true,
        )

        // 完了済みOccurrenceはロックされている
        #expect(plan.locked.count == 2)
        #expect(plan.locked.contains(where: { $0.id == completedJune.id }))
        #expect(plan.locked.contains(where: { $0.id == completedJuly.id }))

        // 1月〜5月のOccurrenceが新規作成される（backfill）
        let backfilledOccurrences = plan.created.filter { occurrence in
            occurrence.scheduledDate < originalFirstDate
        }
        #expect(backfilledOccurrences.count == 5)

        // 1月のOccurrenceが存在することを確認
        let januaryOccurrence = plan.occurrences.first { $0.scheduledDate.month == 1 }
        #expect(januaryOccurrence != nil)
        #expect(januaryOccurrence?.scheduledDate.year == 2025)
    }

    @Test("開始日を過去に変更しても、完了済みOccurrenceは保護される")
    internal func synchronizationPlan_preservesCompletedOccurrencesOnBackfill() throws {
        let newFirstDate = try #require(Date.from(year: 2024, month: 6, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "年会費",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: newFirstDate,
        )

        // 2025年6月のOccurrenceが完了済み
        let completedDate = try #require(Date.from(year: 2025, month: 6, day: 1))
        let completedOccurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: completedDate,
            expectedAmount: 10000,
            status: .completed,
            actualDate: completedDate,
            actualAmount: 10000,
        )
        definition.occurrences = [completedOccurrence]

        let plan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 24,
            backfillFromFirstDate: true,
        )

        // 完了済みOccurrenceはロックされて保護される
        #expect(plan.locked.count == 1)
        #expect(plan.locked.first?.id == completedOccurrence.id)

        // 2024年6月のOccurrenceが生成される（backfill）
        let backfilledOccurrence = plan.occurrences.first { $0.scheduledDate < completedDate }
        #expect(backfilledOccurrence != nil)
        #expect(backfilledOccurrence?.scheduledDate.year == 2024)
        #expect(backfilledOccurrence?.scheduledDate.month == 6)
    }
}
