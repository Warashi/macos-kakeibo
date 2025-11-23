import Foundation

internal protocol RecurringPaymentOccurrencesService: Sendable {
    @discardableResult
    func synchronizeOccurrences(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
    ) async throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary?
}

internal struct RecurringPaymentOccurrencesServiceImpl: RecurringPaymentOccurrencesService {
    private let repository: RecurringPaymentRepository

    internal init(repository: RecurringPaymentRepository) {
        self.repository = repository
    }

    internal func synchronizeOccurrences(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
    ) async throws -> RecurringPaymentSynchronizationSummary {
        try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate,
            backfillFromFirstDate: false,
        )
    }

    internal func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary {
        try await repository.markOccurrenceCompleted(
            occurrenceId: occurrenceId,
            input: input,
            horizonMonths: horizonMonths,
        )
    }

    internal func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary? {
        try await repository.updateOccurrence(
            occurrenceId: occurrenceId,
            input: input,
            horizonMonths: horizonMonths,
        )
    }
}
