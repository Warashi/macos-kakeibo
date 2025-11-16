import Foundation
import Testing

@testable import Kakeibo

@Suite("RecurringPaymentReconciliationPresenter")
internal struct ReconciliationPresenterTests {
    @Test("makePresentation builds sorted rows and lookups")
    internal func makePresentation_buildsRows() throws {
        let presenter = RecurringPaymentReconciliationPresenter()
        let definition = RecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 5, day: 1) ?? Date(),
        )
        let earlier = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 5, day: 1) ?? Date(),
            expectedAmount: 45000,
            status: .planned,
        )
        let later = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5, day: 1) ?? Date(),
            expectedAmount: 46000,
            status: .saving,
        )
        definition.occurrences = [later, earlier]

        let definitionDTO = RecurringPaymentDefinitionDTO(from: definition)
        let earlierDTO = RecurringPaymentOccurrenceDTO(from: earlier)
        let laterDTO = RecurringPaymentOccurrenceDTO(from: later)

        let input = RecurringPaymentReconciliationPresenter.PresentationInput(
            occurrences: [earlierDTO, laterDTO],
            definitions: [definitionDTO.id: definitionDTO],
            categories: [:],
            transactions: [:],
            referenceDate: Date.from(year: 2025, month: 4, day: 1) ?? Date(),
        )

        let presentation = presenter.makePresentation(input: input)

        #expect(presentation.rows.count == 2)
        #expect(presentation.rows.first?.scheduledDate == earlier.scheduledDate)
        #expect(presentation.occurrenceLookup[earlier.id]?.id == earlierDTO.id)
        #expect(presentation.linkedTransactionLookup.isEmpty)
    }

    @Test("transactionCandidates scores transactions and limits count")
    internal func transactionCandidates_scoresTransactions() throws {
        let presenter = RecurringPaymentReconciliationPresenter()
        let definition = RecurringPaymentDefinition(
            name: "保険料",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
        )
        let occurrence = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 6, day: 10) ?? Date(),
            expectedAmount: 100_000,
            status: .planned,
        )

        let matchingTransactionEntity = TransactionEntity(
            date: Date.from(year: 2025, month: 6, day: 12) ?? Date(),
            title: "保険料",
            amount: -100_000,
        )

        let distantTransactionEntity = TransactionEntity(
            date: Date.from(year: 2025, month: 1, day: 1) ?? Date(),
            title: "別支払い",
            amount: -50000,
        )

        let definitionDTO = RecurringPaymentDefinitionDTO(from: definition)
        let occurrenceDTO = RecurringPaymentOccurrenceDTO(from: occurrence)
        let matchingTransaction = Transaction(from: matchingTransactionEntity)
        let distantTransaction = Transaction(from: distantTransactionEntity)

        let context = RecurringPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: [matchingTransaction, distantTransaction],
            linkedTransactionLookup: [:],
            windowDays: 30,
            limit: 5,
            currentDate: Date.from(year: 2025, month: 12, day: 31) ?? Date(),
        )

        let candidates = presenter.transactionCandidates(
            for: occurrenceDTO,
            definition: definitionDTO,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == matchingTransaction.id)
        #expect(candidates.first?.score.total ?? 0 > 0.5)
    }

    @Test("transactionCandidates excludes future transactions")
    internal func transactionCandidates_excludesFutureTransactions() throws {
        let presenter = RecurringPaymentReconciliationPresenter()
        let definition = RecurringPaymentDefinition(
            name: "保険料",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
        )
        let occurrence = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 6, day: 10) ?? Date(),
            expectedAmount: 100_000,
            status: .planned,
        )

        let pastTransactionEntity = TransactionEntity(
            date: Date.from(year: 2025, month: 6, day: 5) ?? Date(),
            title: "保険料",
            amount: -100_000,
        )

        let futureTransactionEntity = TransactionEntity(
            date: Date.from(year: 2025, month: 6, day: 20) ?? Date(),
            title: "保険料",
            amount: -100_000,
        )

        let definitionDTO = RecurringPaymentDefinitionDTO(from: definition)
        let occurrenceDTO = RecurringPaymentOccurrenceDTO(from: occurrence)
        let pastTransaction = Transaction(from: pastTransactionEntity)
        let futureTransaction = Transaction(from: futureTransactionEntity)

        let context = RecurringPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: [pastTransaction, futureTransaction],
            linkedTransactionLookup: [:],
            windowDays: 30,
            limit: 5,
            currentDate: Date.from(year: 2025, month: 6, day: 15) ?? Date(),
        )

        let candidates = presenter.transactionCandidates(
            for: occurrenceDTO,
            definition: definitionDTO,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == pastTransaction.id)
    }
}
