import Foundation
@testable import Kakeibo

@DatabaseActor
internal final class SpyRecurringPaymentOccurrencesService: RecurringPaymentOccurrencesService {
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

    private let wrapped: RecurringPaymentOccurrencesService

    internal private(set) var synchronizeCalls: [SynchronizeCall] = []
    internal private(set) var markCompletionCalls: [MarkCompletionCall] = []
    internal private(set) var updateCalls: [UpdateCall] = []

    internal init(wrapping service: RecurringPaymentOccurrencesService) {
        self.wrapped = service
    }

    @discardableResult
    internal func synchronizeOccurrences(
        for definition: RecurringPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> RecurringPaymentSynchronizationSummary {
        synchronizeCalls.append(
            SynchronizeCall(
                definitionId: definition.id,
                horizonMonths: horizonMonths,
                referenceDate: referenceDate,
            ),
        )
        return try wrapped.synchronizeOccurrences(
            for: definition,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate,
        )
    }

    @discardableResult
    internal func markOccurrenceCompleted(
        _ occurrence: RecurringPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary {
        markCompletionCalls.append(
            MarkCompletionCall(
                occurrenceId: occurrence.id,
                input: input,
                horizonMonths: horizonMonths,
            ),
        )
        return try wrapped.markOccurrenceCompleted(
            occurrence,
            input: input,
            horizonMonths: horizonMonths,
        )
    }

    @discardableResult
    internal func updateOccurrence(
        _ occurrence: RecurringPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary? {
        updateCalls.append(
            UpdateCall(
                occurrenceId: occurrence.id,
                input: input,
                horizonMonths: horizonMonths,
            ),
        )
        return try wrapped.updateOccurrence(
            occurrence,
            input: input,
            horizonMonths: horizonMonths,
        )
    }
}
