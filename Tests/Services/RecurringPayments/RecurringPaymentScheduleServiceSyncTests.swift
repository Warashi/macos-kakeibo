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

    @Test("開始日を未来に変更した場合、新しい開始日より前のOccurrenceは削除される")
    internal func synchronizationPlan_removesOccurrencesBeforeNewStartDate() throws {
        let oldFirstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let newFirstDate = try #require(Date.from(year: 2025, month: 6, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "月額サブスクリプション",
            amount: 1000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: newFirstDate, // 未来に変更後の開始日
        )

        // 1月〜5月のOccurrenceが既に存在（古い開始日で生成されたもの）
        let januaryOccurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: oldFirstDate,
            expectedAmount: 1000,
            status: .planned,
        )
        let februaryDate = try #require(Date.from(year: 2025, month: 2, day: 1))
        let februaryOccurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: februaryDate,
            expectedAmount: 1000,
            status: .planned,
        )
        definition.occurrences = [januaryOccurrence, februaryOccurrence]

        let plan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 12,
            backfillFromFirstDate: false,
        )

        // 新しい開始日より前のOccurrenceは削除される
        #expect(plan.removed.count == 2)
        #expect(plan.removed.contains(where: { $0.id == januaryOccurrence.id }))
        #expect(plan.removed.contains(where: { $0.id == februaryOccurrence.id }))

        // 6月以降のOccurrenceが生成される
        let juneOccurrence = plan.occurrences.first { $0.scheduledDate.month == 6 }
        #expect(juneOccurrence != nil)
        #expect(juneOccurrence?.scheduledDate.year == 2025)
    }

    @Test("開始日を未来に変更しても、完了済みOccurrenceは保護される")
    internal func synchronizationPlan_preservesCompletedOccurrencesWhenMovingStartDateForward() throws {
        let oldFirstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let newFirstDate = try #require(Date.from(year: 2025, month: 6, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 3, day: 1))

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "月額サブスクリプション",
            amount: 1000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: newFirstDate, // 未来に変更後の開始日
        )

        // 1月と2月のOccurrenceは完了済み
        let januaryOccurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: oldFirstDate,
            expectedAmount: 1000,
            status: .completed,
            actualDate: oldFirstDate,
            actualAmount: 1000,
        )
        let februaryDate = try #require(Date.from(year: 2025, month: 2, day: 1))
        let februaryOccurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: februaryDate,
            expectedAmount: 1000,
            status: .completed,
            actualDate: februaryDate,
            actualAmount: 1000,
        )
        // 3月は未完了
        let marchDate = try #require(Date.from(year: 2025, month: 3, day: 1))
        let marchOccurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: marchDate,
            expectedAmount: 1000,
            status: .planned,
        )
        definition.occurrences = [januaryOccurrence, februaryOccurrence, marchOccurrence]

        let plan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 12,
            backfillFromFirstDate: false,
        )

        // 完了済みOccurrenceはロックされて保護される
        #expect(plan.locked.count == 2)
        #expect(plan.locked.contains(where: { $0.id == januaryOccurrence.id }))
        #expect(plan.locked.contains(where: { $0.id == februaryOccurrence.id }))

        // 未完了の3月のOccurrenceは削除される
        #expect(plan.removed.contains(where: { $0.id == marchOccurrence.id }))

        // 6月以降のOccurrenceが生成される
        let futureOccurrences = plan.created.filter { $0.scheduledDate >= newFirstDate }
        #expect(futureOccurrences.isEmpty == false)
    }

    @Test("開始日を過去に変更後、最も古いOccurrenceを突合しても、途中のOccurrenceが自動的に生成される")
    internal func synchronizationPlan_autoBackfillsGapsAfterCompletingOldestOccurrence() throws {
        let originalFirstDate = try #require(Date.from(year: 2025, month: 4, day: 1))
        let newFirstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 12, day: 1))

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "月額サブスクリプション",
            amount: 1000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: newFirstDate,
        )

        // 初期状態: 4月と5月のOccurrenceが完了済み
        let completedApril = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: originalFirstDate,
            expectedAmount: 1000,
            status: .completed,
            actualDate: originalFirstDate,
            actualAmount: 1000,
        )
        let mayDate = try #require(Date.from(year: 2025, month: 5, day: 1))
        let completedMay = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: mayDate,
            expectedAmount: 1000,
            status: .completed,
            actualDate: mayDate,
            actualAmount: 1000,
        )
        definition.occurrences = [completedApril, completedMay]

        // 1回目の同期: backfillFromFirstDate = true で1月〜3月のOccurrenceを生成
        let firstSyncPlan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 12,
            backfillFromFirstDate: true,
        )

        // 1月〜3月のOccurrenceが生成されることを確認
        let backfilledOccurrences = firstSyncPlan.created.filter { occurrence in
            occurrence.scheduledDate < originalFirstDate
        }
        #expect(backfilledOccurrences.count == 3)

        // 定義のOccurrenceリストを更新（実際のリポジトリではこれが自動的に行われる）
        definition.occurrences = firstSyncPlan.occurrences

        // 1月のOccurrenceを完了済みにする（最も古いOccurrenceを突合）
        let januaryOccurrence = try #require(
            definition.occurrences.first { $0.scheduledDate.month == 1 },
        )
        januaryOccurrence.status = .completed
        januaryOccurrence.actualDate = januaryOccurrence.scheduledDate
        januaryOccurrence.actualAmount = 1000

        // 2回目の同期: backfillFromFirstDate = false で通常の同期
        // 改善後のnextSeedDateロジックにより、firstOccurrenceDateから自動的に生成される
        let secondSyncPlan = service.synchronizationPlan(
            for: definition,
            referenceDate: referenceDate,
            horizonMonths: 12,
            backfillFromFirstDate: false,
        )

        // 2月と3月のOccurrenceが保持されている（または再生成されている）ことを確認
        let februaryOccurrence = secondSyncPlan.occurrences.first { $0.scheduledDate.month == 2 }
        let marchOccurrence = secondSyncPlan.occurrences.first { $0.scheduledDate.month == 3 }
        #expect(februaryOccurrence != nil, "2月のOccurrenceが存在する")
        #expect(marchOccurrence != nil, "3月のOccurrenceが存在する")

        // 完了済みOccurrenceがロックされていることを確認
        #expect(secondSyncPlan.locked.count == 3) // 1月、4月、5月
        #expect(secondSyncPlan.locked.contains(where: { $0.id == januaryOccurrence.id }))
        #expect(secondSyncPlan.locked.contains(where: { $0.id == completedApril.id }))
        #expect(secondSyncPlan.locked.contains(where: { $0.id == completedMay.id }))
    }
}
