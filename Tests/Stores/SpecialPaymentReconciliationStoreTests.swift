import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentReconciliationStoreTests {
    @Test("読み込み時に未完了のOccurrenceが優先される")
    internal func refreshPrioritizesPendingOccurrences() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context, _) = try makeStore(referenceDate: referenceDate)

        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: referenceDate,
        )
        context.insert(definition)

        let pending = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: referenceDate,
            expectedAmount: 120_000,
            status: .planned,
        )
        let completed = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: referenceDate.addingTimeInterval(-60 * 60 * 24 * 100),
            expectedAmount: 120_000,
            status: .completed,
            actualDate: referenceDate.addingTimeInterval(-60 * 60 * 24 * 100),
            actualAmount: 118_000,
        )
        definition.occurrences = [pending, completed]
        try context.save()

        store.refresh()
        store.filter = .all

        let rows = store.filteredRows
        #expect(rows.count == 2)
        #expect(rows.first?.id == pending.id)
        #expect(rows.last?.id == completed.id)
        #expect(rows.first?.needsAttention == true)
        #expect(rows.last?.isCompleted == true)
    }

    @Test("候補スコアリングは金額と日付が近い取引を優先する")
    internal func candidateScoringPrefersCloseMatches() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 4, day: 10))
        let (store, context, _) = try makeStore(referenceDate: referenceDate)

        let definition = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: referenceDate,
        )
        context.insert(definition)

        let occurrence = SpecialPaymentOccurrence(
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
            date: referenceDate.addingTimeInterval(60 * 60 * 24 * 30),
            title: "別支出",
            amount: -170_000,
            memo: "",
        )

        context.insert(perfectMatch)
        context.insert(farMatch)
        try context.save()

        store.refresh()
        store.selectedOccurrenceId = occurrence.id

        let candidates = store.candidateTransactions
        #expect(candidates.count >= 1)
        #expect(candidates.first?.transaction.id == perfectMatch.id)
        #expect(candidates.first?.score.total ?? 0 > (candidates.last?.score.total ?? 0))
    }

    @Test("実績保存で取引が紐付けられ完了状態になる")
    internal func saveSelectedOccurrenceLinksTransaction() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 2, day: 15))
        let (store, context, spy) = try makeStore(referenceDate: referenceDate)

        let definition = SpecialPaymentDefinition(
            name: "旅行積立",
            amount: 80000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: referenceDate,
        )
        context.insert(definition)

        let occurrence = SpecialPaymentOccurrence(
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

        store.refresh()
        store.selectedOccurrenceId = occurrence.id
        store.selectCandidate(transaction.id)
        store.actualAmountText = transaction.absoluteAmount.plainString
        store.actualDate = referenceDate

        store.saveSelectedOccurrence()

        #expect(occurrence.status == .completed)
        #expect(occurrence.transaction?.id == transaction.id)
        #expect(occurrence.actualAmount == transaction.absoluteAmount)
        #expect(store.errorMessage == nil)
        #expect(spy.markCompletionCalls.count == 1)
    }

    @Test("リンク解除で未完了に戻りサービス経由で更新される")
    internal func unlinkSelectedOccurrenceResetsActuals() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 6, day: 1))
        let (store, context, spy) = try makeStore(referenceDate: referenceDate)

        let definition = SpecialPaymentDefinition(
            name: "大型備品",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: referenceDate,
            leadTimeMonths: 0
        )
        context.insert(definition)

        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: referenceDate,
            expectedAmount: 100_000,
            status: .completed,
            actualDate: referenceDate,
            actualAmount: 100_000
        )
        definition.occurrences = [occurrence]

        let transaction = Transaction(
            date: referenceDate,
            title: "大型備品支払い",
            amount: -100_000,
            memo: ""
        )
        occurrence.transaction = transaction
        context.insert(transaction)
        try context.save()

        store.refresh()
        store.selectedOccurrenceId = occurrence.id
        store.unlinkSelectedOccurrence()

        #expect(occurrence.status == .planned)
        #expect(occurrence.transaction == nil)
        #expect(occurrence.actualAmount == nil)
        #expect(spy.updateCalls.count == 1)
        #expect(store.errorMessage == nil)
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) throws -> (SpecialPaymentReconciliationStore, ModelContext, SpySpecialPaymentOccurrencesService) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SpecialPaymentRepositoryFactory.make(
            modelContext: context,
            currentDateProvider: { referenceDate }
        )
        let baseService = DefaultSpecialPaymentOccurrencesService(repository: repository)
        let spyService = SpySpecialPaymentOccurrencesService(wrapping: baseService)
        let store = SpecialPaymentReconciliationStore(
            repository: repository,
            transactionRepository: SwiftDataTransactionRepository(modelContext: context),
            occurrencesService: spyService,
            currentDateProvider: { referenceDate },
        )
        return (store, context, spyService)
    }
}
