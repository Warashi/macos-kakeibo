import Foundation
import Testing

@testable import Kakeibo

@Suite("RecurringPaymentReconciliationPresenter")
internal struct ReconciliationPresenterTests {
    @Test("makePresentation builds sorted rows and lookups")
    internal func makePresentation_buildsRows() throws {
        let presenter = RecurringPaymentReconciliationPresenter()
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 5, day: 1) ?? Date(),
        )
        let earlier = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 5, day: 1) ?? Date(),
            expectedAmount: 45000,
            status: .planned,
        )
        let later = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5, day: 1) ?? Date(),
            expectedAmount: 46000,
            status: .saving,
        )
        definition.occurrences = [later, earlier]

        let definitionModel = RecurringPaymentDefinition(from: definition)
        let earlierModel = RecurringPaymentOccurrence(from: earlier)
        let laterModel = RecurringPaymentOccurrence(from: later)

        let input = RecurringPaymentReconciliationPresenter.PresentationInput(
            occurrences: [earlierModel, laterModel],
            definitions: [definitionModel.id: definitionModel],
            categories: [:],
            transactions: [:],
            referenceDate: Date.from(year: 2025, month: 4, day: 1) ?? Date(),
        )

        let presentation = presenter.makePresentation(input: input)

        #expect(presentation.rows.count == 2)
        #expect(presentation.rows.first?.scheduledDate == earlier.scheduledDate)
        #expect(presentation.occurrenceLookup[earlier.id]?.id == earlierModel.id)
        #expect(presentation.linkedTransactionLookup.isEmpty)
    }

    @Test("transactionCandidates scores transactions and limits count")
    internal func transactionCandidates_scoresTransactions() throws {
        let presenter = RecurringPaymentReconciliationPresenter()
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "保険料",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
        )
        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 6, day: 10) ?? Date(),
            expectedAmount: 100_000,
            status: .planned,
        )

        let matchingSwiftDataTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 12) ?? Date(),
            title: "保険料",
            amount: -100_000,
        )

        let distantSwiftDataTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 1, day: 1) ?? Date(),
            title: "別支払い",
            amount: -50000,
        )

        let definitionModel = RecurringPaymentDefinition(from: definition)
        let occurrenceModel = RecurringPaymentOccurrence(from: occurrence)
        let matchingTransaction = Transaction(from: matchingSwiftDataTransaction)
        let distantTransaction = Transaction(from: distantSwiftDataTransaction)

        let context = RecurringPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: [matchingTransaction, distantTransaction],
            linkedTransactionLookup: [:],
            windowDays: 30,
            limit: 5,
            currentDate: Date.from(year: 2025, month: 12, day: 31) ?? Date(),
        )

        let candidates = presenter.transactionCandidates(
            for: occurrenceModel,
            definition: definitionModel,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == matchingTransaction.id)
        #expect(candidates.first?.score.total ?? 0 > 0.5)
    }

    @Test("transactionCandidates excludes future transactions")
    internal func transactionCandidates_excludesFutureTransactions() throws {
        let presenter = RecurringPaymentReconciliationPresenter()
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "保険料",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
        )
        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 6, day: 10) ?? Date(),
            expectedAmount: 100_000,
            status: .planned,
        )

        let pastSwiftDataTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 5) ?? Date(),
            title: "保険料",
            amount: -100_000,
        )

        let futureSwiftDataTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 20) ?? Date(),
            title: "保険料",
            amount: -100_000,
        )

        let definitionModel = RecurringPaymentDefinition(from: definition)
        let occurrenceModel = RecurringPaymentOccurrence(from: occurrence)
        let pastTransaction = Transaction(from: pastSwiftDataTransaction)
        let futureTransaction = Transaction(from: futureSwiftDataTransaction)

        let context = RecurringPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: [pastTransaction, futureTransaction],
            linkedTransactionLookup: [:],
            windowDays: 30,
            limit: 5,
            currentDate: Date.from(year: 2025, month: 6, day: 15) ?? Date(),
        )

        let candidates = presenter.transactionCandidates(
            for: occurrenceModel,
            definition: definitionModel,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == pastTransaction.id)
    }
}
