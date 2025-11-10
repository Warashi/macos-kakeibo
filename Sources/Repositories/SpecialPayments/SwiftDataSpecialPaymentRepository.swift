import Foundation
import SwiftData

internal final class SwiftDataSpecialPaymentRepository: SpecialPaymentRepository {
    private let modelContext: ModelContext
    private let scheduleService: SpecialPaymentScheduleService
    private let currentDateProvider: () -> Date

    internal init(
        modelContext: ModelContext,
        scheduleService: SpecialPaymentScheduleService = SpecialPaymentScheduleService(),
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.modelContext = modelContext
        self.scheduleService = scheduleService
        self.currentDateProvider = currentDateProvider
    }

    internal func definitions(filter: SpecialPaymentDefinitionFilter?) throws -> [SpecialPaymentDefinition] {
        var descriptor = FetchDescriptor<SpecialPaymentDefinition>(
            sortBy: [
                SortDescriptor(\SpecialPaymentDefinition.createdAt, order: .reverse),
            ]
        )
        if let predicate = definitionPredicate(for: filter) {
            descriptor.predicate = predicate
        }

        var results = try modelContext.fetch(descriptor)
        if let searchText = filter?.searchText?.lowercased(), !searchText.isEmpty {
            results = results.filter { $0.name.lowercased().contains(searchText) }
        }

        if let categoryIds = filter?.categoryIds, !categoryIds.isEmpty {
            results = results.filter { definition in
                guard let categoryId = definition.category?.id else {
                    return false
                }
                return categoryIds.contains(categoryId)
            }
        }

        return results
    }

    internal func occurrences(query: SpecialPaymentOccurrenceQuery?) throws -> [SpecialPaymentOccurrence] {
        var descriptor = FetchDescriptor<SpecialPaymentOccurrence>(
            sortBy: [
                SortDescriptor(\SpecialPaymentOccurrence.scheduledDate),
                SortDescriptor(\SpecialPaymentOccurrence.createdAt),
            ]
        )

        if let predicate = occurrencePredicate(for: query) {
            descriptor.predicate = predicate
        }

        var results = try modelContext.fetch(descriptor)

        if let statuses = query?.statusFilter, !statuses.isEmpty {
            results = results.filter { statuses.contains($0.status) }
        }

        if let definitionIds = query?.definitionIds, !definitionIds.isEmpty {
            results = results.filter { definitionIds.contains($0.definition.id) }
        }

        return results
    }

    internal func balances(query: SpecialPaymentBalanceQuery?) throws -> [SpecialPaymentSavingBalance] {
        var descriptor = FetchDescriptor<SpecialPaymentSavingBalance>(
            sortBy: [
                SortDescriptor(\SpecialPaymentSavingBalance.updatedAt, order: .reverse),
            ]
        )

        if let predicate = balancePredicate(for: query) {
            descriptor.predicate = predicate
        }

        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    internal func synchronize(
        definition: SpecialPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date? = nil
    ) throws -> SpecialPaymentSynchronizationSummary {
        guard definition.recurrenceIntervalMonths > 0 else {
            throw SpecialPaymentDomainError.invalidRecurrence
        }
        guard horizonMonths >= 0 else {
            throw SpecialPaymentDomainError.invalidHorizon
        }

        let now = referenceDate ?? currentDateProvider()
        let plan = scheduleService.synchronizationPlan(
            for: definition,
            referenceDate: now,
            horizonMonths: horizonMonths
        )

        guard !plan.occurrences.isEmpty else {
            return SpecialPaymentSynchronizationSummary(
                syncedAt: now,
                createdCount: 0,
                updatedCount: 0,
                removedCount: 0
            )
        }

        plan.created.forEach { modelContext.insert($0) }
        plan.removed.forEach { modelContext.delete($0) }

        definition.occurrences = plan.occurrences
        definition.updatedAt = now

        try modelContext.save()

        return SpecialPaymentSynchronizationSummary(
            syncedAt: now,
            createdCount: plan.created.count,
            updatedCount: plan.updated.count,
            removedCount: plan.removed.count
        )
    }

    @discardableResult
    internal func markOccurrenceCompleted(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int
    ) throws -> SpecialPaymentSynchronizationSummary {
        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        occurrence.transaction = input.transaction
        occurrence.status = .completed
        occurrence.updatedAt = currentDateProvider()

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
        }

        try modelContext.save()

        return try synchronize(
            definition: occurrence.definition,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider()
        )
    }

    @discardableResult
    internal func updateOccurrence(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int
    ) throws -> SpecialPaymentSynchronizationSummary? {
        let now = currentDateProvider()
        let wasCompleted = occurrence.status == .completed
        let willBeCompleted = input.status == .completed

        occurrence.status = input.status
        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        occurrence.transaction = input.transaction
        occurrence.updatedAt = now

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
        }

        try modelContext.save()

        guard wasCompleted != willBeCompleted else {
            return nil
        }

        return try synchronize(
            definition: occurrence.definition,
            horizonMonths: horizonMonths,
            referenceDate: now
        )
    }

    internal func saveChanges() throws {
        try modelContext.save()
    }
}

private extension SwiftDataSpecialPaymentRepository {
    func definitionPredicate(
        for filter: SpecialPaymentDefinitionFilter?
    ) -> Predicate<SpecialPaymentDefinition>? {
        guard let identifiers = filter?.ids, !identifiers.isEmpty else {
            return nil
        }

        return #Predicate<SpecialPaymentDefinition> { definition in
            identifiers.contains(definition.id)
        }
    }

    func occurrencePredicate(
        for query: SpecialPaymentOccurrenceQuery?
    ) -> Predicate<SpecialPaymentOccurrence>? {
        guard let range = query?.range else {
            return nil
        }

        let start = range.startDate
        let end = range.endDate

        return #Predicate<SpecialPaymentOccurrence> { occurrence in
            occurrence.scheduledDate >= start && occurrence.scheduledDate <= end
        }
    }

    func balancePredicate(
        for query: SpecialPaymentBalanceQuery?
    ) -> Predicate<SpecialPaymentSavingBalance>? {
        guard let identifiers = query?.definitionIds, !identifiers.isEmpty else {
            return nil
        }

        return #Predicate<SpecialPaymentSavingBalance> { balance in
            identifiers.contains(balance.definition.id)
        }
    }
}
