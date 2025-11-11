import Foundation
@testable import Kakeibo

internal final class SpySpecialPaymentOccurrencesService: SpecialPaymentOccurrencesService {
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

    private let wrapped: SpecialPaymentOccurrencesService

    internal private(set) var synchronizeCalls: [SynchronizeCall] = []
    internal private(set) var markCompletionCalls: [MarkCompletionCall] = []
    internal private(set) var updateCalls: [UpdateCall] = []

    internal init(wrapping service: SpecialPaymentOccurrencesService) {
        self.wrapped = service
    }

    @discardableResult
    internal func synchronizeOccurrences(
        for definition: SpecialPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> SpecialPaymentSynchronizationSummary {
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
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> SpecialPaymentSynchronizationSummary {
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
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> SpecialPaymentSynchronizationSummary? {
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
