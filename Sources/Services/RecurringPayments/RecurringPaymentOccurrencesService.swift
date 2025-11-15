import Foundation

@DatabaseActor
internal protocol SpecialPaymentOccurrencesService: Sendable {
    @discardableResult
    func synchronizeOccurrences(
        for definition: SpecialPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> SpecialPaymentSynchronizationSummary

    @discardableResult
    func markOccurrenceCompleted(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> SpecialPaymentSynchronizationSummary

    @discardableResult
    func updateOccurrence(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> SpecialPaymentSynchronizationSummary?
}

@DatabaseActor
internal final class DefaultSpecialPaymentOccurrencesService: SpecialPaymentOccurrencesService {
    private let repository: SpecialPaymentRepository

    internal init(repository: SpecialPaymentRepository) {
        self.repository = repository
    }

    internal func synchronizeOccurrences(
        for definition: SpecialPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> SpecialPaymentSynchronizationSummary {
        guard definition.recurrenceIntervalMonths > 0 else {
            throw SpecialPaymentDomainError.invalidRecurrence
        }

        guard horizonMonths >= 0 else {
            throw SpecialPaymentDomainError.invalidHorizon
        }

        return try repository.synchronize(
            definitionId: definition.id,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate,
        )
    }

    internal func markOccurrenceCompleted(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> SpecialPaymentSynchronizationSummary {
        try repository.markOccurrenceCompleted(
            occurrenceId: occurrence.id,
            input: input,
            horizonMonths: horizonMonths,
        )
    }

    internal func updateOccurrence(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> SpecialPaymentSynchronizationSummary? {
        try repository.updateOccurrence(
            occurrenceId: occurrence.id,
            input: input,
            horizonMonths: horizonMonths,
        )
    }
}
