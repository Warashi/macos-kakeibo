import Foundation
@testable import Kakeibo

internal actor SpyRecurringPaymentOccurrencesService: RecurringPaymentOccurrencesService {
    internal struct SynchronizeCall {
        internal let definitionId: UUID
        internal let horizonMonths: Int
        internal let referenceDate: Date?
    }

    internal struct MarkCompletionCall {
        internal let occurrenceId: UUID
        internal let input: OccurrenceCompletionInput
        internal let horizonMonths: Int
    }

    internal struct UpdateCall {
        internal let occurrenceId: UUID
        internal let input: OccurrenceUpdateInput
        internal let horizonMonths: Int
    }

    internal struct SkipCall {
        internal let occurrenceId: UUID
        internal let horizonMonths: Int
    }

    private let wrapped: RecurringPaymentOccurrencesService

    internal private(set) var synchronizeCalls: [SynchronizeCall] = []
    internal private(set) var markCompletionCalls: [MarkCompletionCall] = []
    internal private(set) var updateCalls: [UpdateCall] = []
    internal private(set) var skipCalls: [SkipCall] = []

    internal init(wrapping service: RecurringPaymentOccurrencesService) {
        self.wrapped = service
    }

    @discardableResult
    internal func synchronizeOccurrences(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
    ) async throws -> RecurringPaymentSynchronizationSummary {
        synchronizeCalls.append(
            SynchronizeCall(
                definitionId: definitionId,
                horizonMonths: horizonMonths,
                referenceDate: referenceDate,
            ),
        )
        return try await wrapped.synchronizeOccurrences(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate,
        )
    }

    @discardableResult
    internal func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary {
        markCompletionCalls.append(
            MarkCompletionCall(
                occurrenceId: occurrenceId,
                input: input,
                horizonMonths: horizonMonths,
            ),
        )
        return try await wrapped.markOccurrenceCompleted(
            occurrenceId: occurrenceId,
            input: input,
            horizonMonths: horizonMonths,
        )
    }

    @discardableResult
    internal func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary? {
        updateCalls.append(
            UpdateCall(
                occurrenceId: occurrenceId,
                input: input,
                horizonMonths: horizonMonths,
            ),
        )
        return try await wrapped.updateOccurrence(
            occurrenceId: occurrenceId,
            input: input,
            horizonMonths: horizonMonths,
        )
    }

    @discardableResult
    internal func skipOccurrence(
        occurrenceId: UUID,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary {
        skipCalls.append(
            SkipCall(
                occurrenceId: occurrenceId,
                horizonMonths: horizonMonths,
            ),
        )
        return try await wrapped.skipOccurrence(
            occurrenceId: occurrenceId,
            horizonMonths: horizonMonths,
        )
    }
}
