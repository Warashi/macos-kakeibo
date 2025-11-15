import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct RecurringPaymentReconciliationStoreTests {
    @Test("読み込み時に未完了のOccurrenceが優先される")
    internal func refreshPrioritizesPendingOccurrences() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let harness = try await makeStore(referenceDate: referenceDate)
        let store = harness.store
        let context = harness.context

        let definition = RecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: referenceDate,
        )
        context.insert(definition)

        let pending = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: referenceDate.addingTimeInterval(-60 * 60 * 24),
            expectedAmount: 120_000,
            status: .planned,
        )
        let completed = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: referenceDate.addingTimeInterval(-60 * 60 * 24 * 100),
            expectedAmount: 120_000,
            status: .completed,
            actualDate: referenceDate.addingTimeInterval(-60 * 60 * 24 * 100),
            actualAmount: 118_000,
        )
        definition.occurrences = [pending, completed]
        try context.save()

        await store.refresh()
        store.filter = .all

        let rows = store.filteredRows
        #expect(rows.count == 2)
        #expect(rows.first?.id == pending.id)
        #expect(rows.last?.id == completed.id)
        #expect(rows.first?.needsAttention == true)
        #expect(rows.last?.isCompleted == true)
    }

    @Test("候補スコアリングは金額と日付が近い取引を優先する")
    internal func candidateScoringPrefersCloseMatches() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 4, day: 10))
        let harness = try await makeStore(referenceDate: referenceDate)
        let store = harness.store
        let context = harness.context

        let definition = RecurringPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: referenceDate,
        )
        context.insert(definition)

        let occurrence = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: referenceDate,
            expectedAmount: 150_000,
            status: .saving,
        )
        definition.occurrences = [occurrence]

        let perfectMatch = Transaction(
            date: referenceDate,
            title: "固定資産税 支払い",
            amount: -150_000,
            memo: "",
        )

        let farMatch = Transaction(
            date: referenceDate.addingTimeInterval(-60 * 60 * 24 * 30),
            title: "別支出",
            amount: -170_000,
            memo: "",
        )

        context.insert(perfectMatch)
        context.insert(farMatch)
        try context.save()

        await store.refresh()
        store.selectedOccurrenceId = occurrence.id

        let candidates = store.candidateTransactions
        #expect(candidates.count >= 1)
        #expect(candidates.first?.transaction.id == perfectMatch.id)
        #expect(candidates.first?.score.total ?? 0 > (candidates.last?.score.total ?? 0))
    }

    @Test("実績保存で取引が紐付けられ完了状態になる")
    internal func saveSelectedOccurrenceLinksTransaction() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 2, day: 15))
        let harness = try await makeStore(referenceDate: referenceDate)
        let store = harness.store
        let context = harness.context
        let spy = harness.occurrencesService

        let definition = RecurringPaymentDefinition(
            name: "旅行積立",
            amount: 80000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: referenceDate,
        )
        context.insert(definition)

        let occurrence = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: referenceDate,
            expectedAmount: 80000,
            status: .saving,
        )
        definition.occurrences = [occurrence]

        let transaction = Transaction(
            date: referenceDate,
            title: "旅行費用",
            amount: -82000,
            memo: "",
        )
        context.insert(transaction)
        try context.save()

        await store.refresh()
        store.selectedOccurrenceId = occurrence.id
        store.selectCandidate(transaction.id)
        store.actualAmountText = transaction.absoluteAmount.plainString
        store.actualDate = referenceDate

        await store.saveSelectedOccurrence()

        #expect(occurrence.status == .completed)
        #expect(occurrence.transaction?.id == transaction.id)
        #expect(occurrence.actualAmount == transaction.absoluteAmount)
        #expect(store.errorMessage == nil)
        let markCompletionCalls = await spy.markCompletionCalls
        #expect(markCompletionCalls.count == 1)
    }

    @Test("リンク解除で未完了に戻りサービス経由で更新される")
    internal func unlinkSelectedOccurrenceResetsActuals() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 6, day: 1))
        let harness = try await makeStore(referenceDate: referenceDate)
        let store = harness.store
        let context = harness.context
        let spy = harness.occurrencesService

        let definition = RecurringPaymentDefinition(
            name: "大型備品",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: referenceDate,
            leadTimeMonths: 0,
        )
        context.insert(definition)

        let occurrence = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: referenceDate,
            expectedAmount: 100_000,
            status: .completed,
            actualDate: referenceDate,
            actualAmount: 100_000,
        )
        definition.occurrences = [occurrence]

        let transaction = Transaction(
            date: referenceDate,
            title: "大型備品支払い",
            amount: -100_000,
            memo: "",
        )
        occurrence.transaction = transaction
        context.insert(transaction)
        try context.save()

        await store.refresh()
        store.selectedOccurrenceId = occurrence.id
        await store.unlinkSelectedOccurrence()

        #expect(occurrence.status != .completed)
        #expect(occurrence.transaction == nil)
        #expect(occurrence.actualAmount == nil)
        let updateCalls = await spy.updateCalls
        #expect(updateCalls.count == 1)
        #expect(store.errorMessage == nil)
    }

    // MARK: - Helpers

    @MainActor
    private func makeStore(referenceDate: Date) async throws -> ReconciliationStoreHarness {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await RecurringPaymentRepositoryFactory.make(
            modelContext: context,
            currentDateProvider: { referenceDate },
        )
        let baseService = await DefaultRecurringPaymentOccurrencesService(repository: repository)
        let spyService = await SpyRecurringPaymentOccurrencesService(wrapping: baseService)
        let transactionRepository = await SwiftDataTransactionRepository(modelContext: context)
        let store = RecurringPaymentReconciliationStore(
            repository: repository,
            transactionRepository: transactionRepository,
            occurrencesService: spyService,
            horizonMonths: RecurringPaymentScheduleService.defaultHorizonMonths,
            currentDateProvider: { referenceDate },
        )
        return ReconciliationStoreHarness(
            store: store,
            context: context,
            occurrencesService: spyService,
        )
    }
}

private struct ReconciliationStoreHarness {
    let store: RecurringPaymentReconciliationStore
    let context: ModelContext
    let occurrencesService: SpyRecurringPaymentOccurrencesService
}
