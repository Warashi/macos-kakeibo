import Foundation

@DatabaseActor
internal protocol RecurringPaymentOccurrencesService: Sendable {
    @discardableResult
    func synchronizeOccurrences(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary?
}

@DatabaseActor
internal final class DefaultRecurringPaymentOccurrencesService: RecurringPaymentOccurrencesService {
    private let repository: RecurringPaymentRepository

    internal init(repository: RecurringPaymentRepository) {
        self.repository = repository
    }

    internal func synchronizeOccurrences(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> RecurringPaymentSynchronizationSummary {
        try repository.synchronize(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate,
        )
    }

    internal func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary {
        try repository.markOccurrenceCompleted(
            occurrenceId: occurrenceId,
            input: input,
            horizonMonths: horizonMonths,
        )
    }

    internal func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary? {
        try repository.updateOccurrence(
            occurrenceId: occurrenceId,
            input: input,
            horizonMonths: horizonMonths,
        )
    }
}
