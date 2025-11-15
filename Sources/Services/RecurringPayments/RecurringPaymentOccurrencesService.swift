import Foundation

@DatabaseActor
internal protocol RecurringPaymentOccurrencesService: Sendable {
    @discardableResult
    func synchronizeOccurrences(
        for definition: RecurringPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func markOccurrenceCompleted(
        _ occurrence: RecurringPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func updateOccurrence(
        _ occurrence: RecurringPaymentOccurrence,
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
        for definition: RecurringPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> RecurringPaymentSynchronizationSummary {
        guard definition.recurrenceIntervalMonths > 0 else {
            throw RecurringPaymentDomainError.invalidRecurrence
        }

        guard horizonMonths >= 0 else {
            throw RecurringPaymentDomainError.invalidHorizon
        }

        return try repository.synchronize(
            definitionId: definition.id,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate,
        )
    }

    internal func markOccurrenceCompleted(
        _ occurrence: RecurringPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary {
        try repository.markOccurrenceCompleted(
            occurrenceId: occurrence.id,
            input: input,
            horizonMonths: horizonMonths,
        )
    }

    internal func updateOccurrence(
        _ occurrence: RecurringPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary? {
        try repository.updateOccurrence(
            occurrenceId: occurrence.id,
            input: input,
            horizonMonths: horizonMonths,
        )
    }
}
