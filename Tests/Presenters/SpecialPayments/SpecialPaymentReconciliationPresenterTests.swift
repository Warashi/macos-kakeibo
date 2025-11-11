import Foundation
import Testing

@testable import Kakeibo

@Suite("SpecialPaymentReconciliationPresenter")
internal struct ReconciliationPresenterTests {
    @Test("makePresentation builds sorted rows and lookups")
    internal func makePresentation_buildsRows() throws {
        let presenter = SpecialPaymentReconciliationPresenter()
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 5, day: 1) ?? Date(),
        )
        let earlier = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 5, day: 1) ?? Date(),
            expectedAmount: 45000,
            status: .planned,
        )
        let later = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5, day: 1) ?? Date(),
            expectedAmount: 46000,
            status: .saving,
        )
        definition.occurrences = [later, earlier]

        let presentation = presenter.makePresentation(
            definitions: [definition],
            referenceDate: Date.from(year: 2025, month: 4, day: 1) ?? Date(),
        )

        #expect(presentation.rows.count == 2)
        #expect(presentation.rows.first?.scheduledDate == earlier.scheduledDate)
        #expect(presentation.occurrenceLookup[earlier.id] === earlier)
        #expect(presentation.linkedTransactionLookup.isEmpty)
    }

    @Test("transactionCandidates scores transactions and limits count")
    internal func transactionCandidates_scoresTransactions() throws {
        let presenter = SpecialPaymentReconciliationPresenter()
        let definition = SpecialPaymentDefinition(
            name: "保険料",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
        )
        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 6, day: 10) ?? Date(),
            expectedAmount: 100_000,
            status: .planned,
        )

        let matchingTransaction = Transaction(
            date: Date.from(year: 2025, month: 6, day: 12) ?? Date(),
            title: "保険料",
            amount: -100_000,
        )

        let distantTransaction = Transaction(
            date: Date.from(year: 2025, month: 1, day: 1) ?? Date(),
            title: "別支払い",
            amount: -50000,
        )

        let context = SpecialPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: [matchingTransaction, distantTransaction],
            linkedTransactionLookup: [:],
            windowDays: 30,
            limit: 5,
        )

        let candidates = presenter.transactionCandidates(
            for: occurrence,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == matchingTransaction.id)
        #expect(candidates.first?.score.total ?? 0 > 0.5)
    }
}
