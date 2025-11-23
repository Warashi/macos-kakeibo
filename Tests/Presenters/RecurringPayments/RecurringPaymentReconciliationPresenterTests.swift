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
            customAmountRange: nil,
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
            customAmountRange: nil,
        )

        let candidates = presenter.transactionCandidates(
            for: occurrenceModel,
            definition: definitionModel,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == pastTransaction.id)
    }

    @Test("transactionCandidates filters by custom amount range minimum")
    internal func transactionCandidates_filtersAmountRangeMin() throws {
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

        let lowAmountTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 8) ?? Date(),
            title: "保険料",
            amount: -80_000,
        )

        let highAmountTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 12) ?? Date(),
            title: "保険料",
            amount: -120_000,
        )

        let definitionModel = RecurringPaymentDefinition(from: definition)
        let occurrenceModel = RecurringPaymentOccurrence(from: occurrence)
        let lowTransaction = Transaction(from: lowAmountTransaction)
        let highTransaction = Transaction(from: highAmountTransaction)

        let context = RecurringPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: [lowTransaction, highTransaction],
            linkedTransactionLookup: [:],
            windowDays: 30,
            limit: 5,
            currentDate: Date.from(year: 2025, month: 12, day: 31) ?? Date(),
            customAmountRange: (min: Decimal(100_000), max: nil),
        )

        let candidates = presenter.transactionCandidates(
            for: occurrenceModel,
            definition: definitionModel,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == highTransaction.id)
    }

    @Test("transactionCandidates filters by custom amount range maximum")
    internal func transactionCandidates_filtersAmountRangeMax() throws {
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

        let lowAmountTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 8) ?? Date(),
            title: "保険料",
            amount: -80_000,
        )

        let highAmountTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 12) ?? Date(),
            title: "保険料",
            amount: -120_000,
        )

        let definitionModel = RecurringPaymentDefinition(from: definition)
        let occurrenceModel = RecurringPaymentOccurrence(from: occurrence)
        let lowTransaction = Transaction(from: lowAmountTransaction)
        let highTransaction = Transaction(from: highAmountTransaction)

        let context = RecurringPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: [lowTransaction, highTransaction],
            linkedTransactionLookup: [:],
            windowDays: 30,
            limit: 5,
            currentDate: Date.from(year: 2025, month: 12, day: 31) ?? Date(),
            customAmountRange: (min: nil, max: Decimal(100_000)),
        )

        let candidates = presenter.transactionCandidates(
            for: occurrenceModel,
            definition: definitionModel,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == lowTransaction.id)
    }

    @Test("transactionCandidates filters by custom amount range both min and max")
    internal func transactionCandidates_filtersAmountRangeBoth() throws {
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

        let tooLowTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 5) ?? Date(),
            title: "保険料",
            amount: -70_000,
        )

        let justRightTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 8) ?? Date(),
            title: "保険料",
            amount: -95_000,
        )

        let tooHighTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 6, day: 12) ?? Date(),
            title: "保険料",
            amount: -130_000,
        )

        let definitionModel = RecurringPaymentDefinition(from: definition)
        let occurrenceModel = RecurringPaymentOccurrence(from: occurrence)
        let tooLow = Transaction(from: tooLowTransaction)
        let justRight = Transaction(from: justRightTransaction)
        let tooHigh = Transaction(from: tooHighTransaction)

        let context = RecurringPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: [tooLow, justRight, tooHigh],
            linkedTransactionLookup: [:],
            windowDays: 30,
            limit: 5,
            currentDate: Date.from(year: 2025, month: 12, day: 31) ?? Date(),
            customAmountRange: (min: Decimal(80_000), max: Decimal(110_000)),
        )

        let candidates = presenter.transactionCandidates(
            for: occurrenceModel,
            definition: definitionModel,
            context: context,
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.transaction.id == justRight.id)
    }
}
